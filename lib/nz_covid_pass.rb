require 'uri'
require 'date'
require 'net/http'
require 'json'
require 'base32'
require 'cose'
require 'cbor'
require 'cwt'
require 'jwt'

class NZCovidPass
  Error = Class.new(StandardError)
  ParseError = Class.new(Error)
  NetworkError = Class.new(Error)
  NotYetValidError = Class.new(Error)
  ExpiredError = Class.new(Error)

  VERSION_IDENTIFIER = "1"

  TRUSTED_ISSUER_IDENTIFIERS = [
    "did:web:nzcp.identity.health.nz",
  ]

  TEST_TRUSTED_ISSUER_IDENTIFIERS = [
    "did:web:nzcp.covid19.health.nz",
  ]

  def initialize(code, allow_test_issuers: false, time: Time.now, cache: nil)
    @code = code
    @allow_test_issuers = allow_test_issuers
    @time = time
    @cache = cache

    verify!
  end

  def verify!
    raise ParseError, "invalid URL format" unless url_components
    raise ParseError, "scheme must be NZCP" unless url_components[:scheme] == "NZCP"
    raise ParseError, "version must be #{VERSION_IDENTIFIER}" unless url_components[:version] == VERSION_IDENTIFIER
    raise ParseError, "ALG must be ES256 (-7)" unless alg == -7
    raise ParseError, "invalid issuer" unless trusted_issuer_identifiers.include?(cwt.iss)
    raise ParseError, "no vc claim" unless vc
    raise ParseError, "invalid vc @context" unless vc["@context"].first == "https://www.w3.org/2018/credentials/v1"
    raise ParseError, "invalid vc type" unless vc["type"] == ["VerifiableCredential", "PublicCovidPass"]
    raise NotYetValidError, "not yet valid" if cwt.nbf > @time.to_i
    raise ExpiredError, "expired" if cwt.exp < @time.to_i
    raise ParseError, "invalid jti" unless jti
    raise ParseError, "credentialSubject missing" unless credential_subject
    raise ParseError, "givenName missing" unless given_name
    raise ParseError, "dob missing" unless dob

    sign1.verify(retrieve_public_key)
  end

  def given_name
    credential_subject["givenName"]
  end

  def family_name
    credential_subject["familyName"]
  end

  def dob
    credential_subject["dob"] && Date.parse(credential_subject["dob"])
  end

  def expiry
    Time.at(cwt.exp).utc.to_datetime
  end

  def jti
    cti = cwt.cti
    if cti.length == 16
      match = cti.unpack("H32").first.match(/^(.{8})(.{4})(.{4})(.{4})(.{12})$/)
      "urn:uuid:#{match.captures.join("-")}"
    end
  end

  def version
    vc["version"]
  end

  private

  def url_components
    if match = @code.match(%r(\A([^:]+):/([^/]+)/([A-Z2-7]+)\z))
      scheme, version, data = match.captures
      {scheme: scheme, version: version, data: data}
    end
  end

  def credential_subject
    vc["credentialSubject"]
  end

  def kid
    sign1.protected_headers.fetch(4)
  end

  def alg
    sign1.protected_headers.fetch(1)
  end

  def sign1
    @sign1 ||= begin
      cbor_data = Base32.decode(url_components[:data])
      COSE::Sign1.deserialize(cbor_data)
    end
  end

  def sign1_payload
    @sign1_payload ||= CBOR.decode(sign1.payload)
  end

  def cwt
    @cwt ||= CWT::ClaimsSet.from_cbor(sign1.payload)
  end

  def vc
    @vc ||= sign1_payload["vc"]
  end

  def retrieve_public_key
    did_data = retrieve_did_document

    key_reference = "#{cwt.iss}##{kid}"
    verification_method = did_data["verificationMethod"].detect { |method| method["id"] == key_reference }

    if verification_method.nil?
      raise ParseError, "No matching verification method found in did document"
    end

    jwk_data = verification_method["publicKeyJwk"]
    jwk = JWT::JWK.import(jwk_data)
    key = COSE::Key.from_pkey(jwk.keypair)

    key.kid = kid
    key
  end

  def retrieve_did_document
    host = cwt.iss.split(":").last

    return @cache[host] if @cache && @cache[host]

    http = Net::HTTP.new(host, 443)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    request = Net::HTTP::Get.new("/.well-known/did.json", {"Accept" => "application/json"})

    response = http.request(request)
    raise NetworkError, "https request returned response code #{response.code}" unless response.code == "200"

    document = JSON.parse(response.body)
    @cache[host] = document if @cache

    document
  end

  def trusted_issuer_identifiers
    if @allow_test_issuers
      TRUSTED_ISSUER_IDENTIFIERS + TEST_TRUSTED_ISSUER_IDENTIFIERS
    else
      TRUSTED_ISSUER_IDENTIFIERS
    end
  end
end
