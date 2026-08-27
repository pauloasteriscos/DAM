import {
  base64UrlDecode,
  base64UrlEncode,
  base64UrlJson,
  concatBytes,
  decodeUtf8,
  lengthPrefixed,
  parseBase64UrlJson,
  sha256,
  uint32,
  utf8,
} from "./encoding";

export type OkpPublicJwk = JsonWebKey & {
  kty: "OKP";
  crv: "Ed25519" | "X25519";
  x: string;
  kid?: string;
};

export type OkpPrivateJwk = OkpPublicJwk & {
  d: string;
};

type CompactJwsHeader = {
  alg: "EdDSA";
  typ: string;
  kid: string;
};

type CompactJweHeader = {
  alg: "ECDH-ES";
  enc: "A256GCM";
  typ: string;
  cty: "JOSE";
  kid: string;
  epk: OkpPublicJwk;
  apu: string;
  apv: string;
};

const aesTagLengthBytes = 16;
const aesNonceLengthBytes = 12;
const maxCompactJoseLength = 512 * 1024;

export function parseOkpJwk(
  raw: string | JsonWebKey | undefined,
  expectedCurve: "Ed25519" | "X25519",
  requirePrivate: boolean,
): OkpPublicJwk | OkpPrivateJwk {
  if (!raw) {
    throw new Error(`Chave ${expectedCurve} não configurada`);
  }

  const parsed = typeof raw === "string" ? JSON.parse(raw) as JsonWebKey : raw;

  if (
    parsed.kty !== "OKP" ||
    parsed.crv !== expectedCurve ||
    typeof parsed.x !== "string" ||
    parsed.x.length === 0
  ) {
    throw new Error(`JWK ${expectedCurve} inválida`);
  }

  if (base64UrlDecode(parsed.x).length !== 32) {
    throw new Error(`Chave pública ${expectedCurve} com tamanho inválido`);
  }

  if (requirePrivate && (typeof parsed.d !== "string" || parsed.d.length === 0)) {
    throw new Error(`JWK privada ${expectedCurve} inválida`);
  }

  if (requirePrivate && base64UrlDecode(parsed.d as string).length !== 32) {
    throw new Error(`Chave privada ${expectedCurve} com tamanho inválido`);
  }

  if (!requirePrivate && parsed.d !== undefined) {
    throw new Error(`A JWK pública ${expectedCurve} não pode conter 'd'`);
  }

  return parsed as OkpPublicJwk | OkpPrivateJwk;
}

export function publicOnlyJwk(jwk: OkpPublicJwk | OkpPrivateJwk): OkpPublicJwk {
  const result: OkpPublicJwk = {
    kty: "OKP",
    crv: jwk.crv,
    x: jwk.x,
  };

  if (jwk.kid) {
    result.kid = jwk.kid;
  }

  return result;
}

async function importEd25519Private(jwk: OkpPrivateJwk): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "Ed25519" },
    false,
    ["sign"],
  );
}

async function importEd25519Public(jwk: OkpPublicJwk): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "Ed25519" },
    false,
    ["verify"],
  );
}

async function importX25519Private(jwk: OkpPrivateJwk): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "X25519" },
    false,
    ["deriveBits"],
  );
}

async function importX25519Public(jwk: OkpPublicJwk): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "X25519" },
    false,
    [],
  );
}

export async function signCompactJws(input: {
  payload: Uint8Array;
  privateJwk: OkpPrivateJwk;
  keyId: string;
  type: string;
}): Promise<string> {
  const header: CompactJwsHeader = {
    alg: "EdDSA",
    typ: input.type,
    kid: input.keyId,
  };
  const protectedPart = base64UrlJson(header);
  const payloadPart = base64UrlEncode(input.payload);
  const signingInput = utf8(`${protectedPart}.${payloadPart}`);
  const privateKey = await importEd25519Private(input.privateJwk);
  const signature = await crypto.subtle.sign("Ed25519", privateKey, signingInput);

  return `${protectedPart}.${payloadPart}.${base64UrlEncode(signature)}`;
}

export async function verifyCompactJws(input: {
  compact: string;
  publicJwk: OkpPublicJwk;
  expectedKeyId: string;
  expectedType: string;
}): Promise<Uint8Array> {
  if (input.compact.length > maxCompactJoseLength) {
    throw new Error("JWS demasiado grande");
  }

  const parts = input.compact.split(".");
  if (parts.length !== 3) {
    throw new Error("JWS Compact inválido");
  }

  const [protectedPart, payloadPart, signaturePart] = parts;
  if (!protectedPart || !payloadPart || !signaturePart) {
    throw new Error("JWS incompleto");
  }

  const header = parseBase64UrlJson<Partial<CompactJwsHeader>>(protectedPart);
  if (
    header.alg !== "EdDSA" ||
    header.typ !== input.expectedType ||
    header.kid !== input.expectedKeyId
  ) {
    throw new Error("Cabeçalho JWS não permitido");
  }

  const publicKey = await importEd25519Public(input.publicJwk);
  const valid = await crypto.subtle.verify(
    "Ed25519",
    publicKey,
    base64UrlDecode(signaturePart),
    utf8(`${protectedPart}.${payloadPart}`),
  );

  if (!valid) {
    throw new Error("Assinatura JWS inválida");
  }

  return base64UrlDecode(payloadPart);
}

async function concatKdfA256Gcm(input: {
  sharedSecret: Uint8Array;
  partyUInfo: Uint8Array;
  partyVInfo: Uint8Array;
}): Promise<Uint8Array> {
  const algorithmId = utf8("A256GCM");
  const keyDataLengthBits = 256;
  const otherInfo = concatBytes(
    lengthPrefixed(algorithmId),
    lengthPrefixed(input.partyUInfo),
    lengthPrefixed(input.partyVInfo),
    uint32(keyDataLengthBits),
  );

  return sha256(concatBytes(uint32(1), input.sharedSecret, otherInfo));
}

async function deriveX25519Secret(input: {
  privateKey: CryptoKey;
  publicKey: CryptoKey;
}): Promise<Uint8Array> {
  return new Uint8Array(
    await crypto.subtle.deriveBits(
      { name: "X25519", public: input.publicKey } as any,
      input.privateKey,
      256,
    ),
  );
}

export async function encryptCompactJwe(input: {
  plaintext: Uint8Array;
  recipientPublicJwk: OkpPublicJwk;
  recipientKeyId: string;
  senderParty: string;
  recipientParty: string;
  type: string;
}): Promise<string> {
  const ephemeralPair = await crypto.subtle.generateKey(
    { name: "X25519" },
    true,
    ["deriveBits"],
  ) as CryptoKeyPair;
  const ephemeralPublic = publicOnlyJwk(
    parseOkpJwk(
      await crypto.subtle.exportKey("jwk", ephemeralPair.publicKey) as JsonWebKey,
      "X25519",
      false,
    ),
  );
  const recipientPublicKey = await importX25519Public(input.recipientPublicJwk);
  const sharedSecret = await deriveX25519Secret({
    privateKey: ephemeralPair.privateKey,
    publicKey: recipientPublicKey,
  });
  const partyUInfo = utf8(input.senderParty);
  const partyVInfo = utf8(input.recipientParty);
  const contentKeyBytes = await concatKdfA256Gcm({
    sharedSecret,
    partyUInfo,
    partyVInfo,
  });
  const header: CompactJweHeader = {
    alg: "ECDH-ES",
    enc: "A256GCM",
    typ: input.type,
    cty: "JOSE",
    kid: input.recipientKeyId,
    epk: ephemeralPublic,
    apu: base64UrlEncode(partyUInfo),
    apv: base64UrlEncode(partyVInfo),
  };
  const protectedPart = base64UrlJson(header);
  const nonce = new Uint8Array(aesNonceLengthBytes);
  crypto.getRandomValues(nonce);
  const aesKey = await crypto.subtle.importKey(
    "raw",
    contentKeyBytes,
    { name: "AES-GCM" },
    false,
    ["encrypt"],
  );
  const cipherAndTag = new Uint8Array(
    await crypto.subtle.encrypt(
      {
        name: "AES-GCM",
        iv: nonce,
        additionalData: utf8(protectedPart),
        tagLength: aesTagLengthBytes * 8,
      },
      aesKey,
      input.plaintext,
    ),
  );
  const cipherText = cipherAndTag.slice(0, -aesTagLengthBytes);
  const tag = cipherAndTag.slice(-aesTagLengthBytes);

  return [
    protectedPart,
    "",
    base64UrlEncode(nonce),
    base64UrlEncode(cipherText),
    base64UrlEncode(tag),
  ].join(".");
}

export async function decryptCompactJwe(input: {
  compact: string;
  recipientPrivateJwk: OkpPrivateJwk;
  expectedRecipientKeyId: string;
  expectedSenderParty: string;
  expectedRecipientParty: string;
  expectedType: string;
}): Promise<Uint8Array> {
  if (input.compact.length > maxCompactJoseLength) {
    throw new Error("JWE demasiado grande");
  }

  const parts = input.compact.split(".");
  if (parts.length !== 5) {
    throw new Error("JWE Compact inválido");
  }

  const [protectedPart, encryptedKeyPart, ivPart, cipherPart, tagPart] = parts;
  if (
    !protectedPart ||
    encryptedKeyPart !== "" ||
    !ivPart ||
    !cipherPart ||
    !tagPart
  ) {
    throw new Error("JWE incompleto");
  }

  const header = parseBase64UrlJson<Partial<CompactJweHeader>>(protectedPart);
  if (
    header.alg !== "ECDH-ES" ||
    header.enc !== "A256GCM" ||
    header.typ !== input.expectedType ||
    header.cty !== "JOSE" ||
    header.kid !== input.expectedRecipientKeyId ||
    typeof header.apu !== "string" ||
    typeof header.apv !== "string" ||
    !header.epk
  ) {
    throw new Error("Cabeçalho JWE não permitido");
  }

  const partyUInfo = base64UrlDecode(header.apu);
  const partyVInfo = base64UrlDecode(header.apv);
  if (
    decodeUtf8(partyUInfo) !== input.expectedSenderParty ||
    decodeUtf8(partyVInfo) !== input.expectedRecipientParty
  ) {
    throw new Error("Contexto JWE inválido");
  }

  const ephemeralPublicJwk = parseOkpJwk(header.epk, "X25519", false) as OkpPublicJwk;
  const recipientPrivateKey = await importX25519Private(input.recipientPrivateJwk);
  const ephemeralPublicKey = await importX25519Public(ephemeralPublicJwk);
  const sharedSecret = await deriveX25519Secret({
    privateKey: recipientPrivateKey,
    publicKey: ephemeralPublicKey,
  });
  const contentKeyBytes = await concatKdfA256Gcm({
    sharedSecret,
    partyUInfo,
    partyVInfo,
  });
  const aesKey = await crypto.subtle.importKey(
    "raw",
    contentKeyBytes,
    { name: "AES-GCM" },
    false,
    ["decrypt"],
  );
  const nonce = base64UrlDecode(ivPart);
  const tag = base64UrlDecode(tagPart);

  if (nonce.length !== aesNonceLengthBytes || tag.length !== aesTagLengthBytes) {
    throw new Error("Parâmetros AES-GCM inválidos");
  }

  try {
    return new Uint8Array(
      await crypto.subtle.decrypt(
        {
          name: "AES-GCM",
          iv: nonce,
          additionalData: utf8(protectedPart),
          tagLength: aesTagLengthBytes * 8,
        },
        aesKey,
        concatBytes(base64UrlDecode(cipherPart), tag),
      ),
    );
  } catch {
    throw new Error("JWE inválido ou adulterado");
  }
}
