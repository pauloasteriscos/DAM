import {
  base64UrlDecode,
  decodeUtf8,
  normalizedHtu,
  parseBase64UrlJson,
  sha256Base64Url,
  utf8,
} from "./encoding";
import {
  parseOkpJwk,
  publicOnlyJwk,
  type OkpPublicJwk,
} from "./jose";

type DpopHeader = {
  typ: "dpop+jwt";
  alg: "EdDSA";
  jwk: OkpPublicJwk;
};

type DpopClaims = {
  jti: string;
  htm: string;
  htu: string;
  iat: number;
  ath?: string;
};

type ClaimsDiagnostic = {
  now: number;
  maxAgeSeconds: number;
  expectedHtm: string;
  expectedHtu: string;
  raw: Record<string, unknown>;
};

function isRecord(
  value: unknown,
): value is Record<string, unknown> {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value)
  );
}

function rejectClaims(
  reason: string,
  diagnostic: ClaimsDiagnostic,
): never {
  const jti = diagnostic.raw.jti;
  const iat = diagnostic.raw.iat;

  console.warn("Diagnóstico DPoP", {
    reason,

    jtiType: typeof jti,
    jtiLength:
      typeof jti === "string"
        ? jti.length
        : null,

    receivedIat: iat,
    currentTime: diagnostic.now,
    ageSeconds:
      typeof iat === "number"
        ? diagnostic.now - iat
        : null,
    maxAgeSeconds: diagnostic.maxAgeSeconds,

    receivedHtm: diagnostic.raw.htm,
    expectedHtm: diagnostic.expectedHtm,

    receivedHtu: diagnostic.raw.htu,
    expectedHtu: diagnostic.expectedHtu,
  });

  throw new Error("Claims DPoP inválidas");
}

function requireStringClaim(
  value: unknown,
  reason: string,
  diagnostic: ClaimsDiagnostic,
): string {
  if (typeof value !== "string") {
    rejectClaims(reason, diagnostic);
  }

  return value;
}

function requireIntegerClaim(
  value: unknown,
  reason: string,
  diagnostic: ClaimsDiagnostic,
): number {
  if (
    typeof value !== "number" ||
    !Number.isInteger(value)
  ) {
    rejectClaims(reason, diagnostic);
  }

  return value;
}

function validateDpopClaims(input: {
  rawClaims: unknown;
  method: string;
  url: string;
  maxAgeSeconds: number;
}): DpopClaims {
  const now = Math.floor(Date.now() / 1000);
  const expectedHtm = input.method.toUpperCase();
  const expectedHtu = normalizedHtu(input.url);

  if (!isRecord(input.rawClaims)) {
    console.warn("Diagnóstico DPoP", {
      reason: "payload DPoP não é um objeto",
      currentTime: now,
      maxAgeSeconds: input.maxAgeSeconds,
      expectedHtm,
      expectedHtu,
    });

    throw new Error("Claims DPoP inválidas");
  }

  const raw: Record<string, unknown> =
    input.rawClaims;

  const diagnostic: ClaimsDiagnostic = {
    now,
    maxAgeSeconds: input.maxAgeSeconds,
    expectedHtm,
    expectedHtu,
    raw,
  };

  const jti = requireStringClaim(
    raw.jti,
    "jti ausente ou não textual",
    diagnostic,
  );

  if (jti.length < 16) {
    rejectClaims("jti demasiado curto", diagnostic);
  }

  if (jti.length > 200) {
    rejectClaims("jti demasiado longo", diagnostic);
  }

  const iat = requireIntegerClaim(
    raw.iat,
    "iat ausente ou inválido",
    diagnostic,
  );

  if (iat < now - input.maxAgeSeconds) {
    rejectClaims("prova DPoP expirada", diagnostic);
  }

  if (iat > now + 60) {
    rejectClaims(
      "iat está demasiado avançado no futuro",
      diagnostic,
    );
  }

  const htm = requireStringClaim(
    raw.htm,
    "htm ausente ou não textual",
    diagnostic,
  );

  if (htm !== expectedHtm) {
    rejectClaims("método HTTP diferente", diagnostic);
  }

  const htu = requireStringClaim(
    raw.htu,
    "htu ausente ou não textual",
    diagnostic,
  );

  if (htu !== expectedHtu) {
    rejectClaims("URL HTTP diferente", diagnostic);
  }

  const athValue = raw.ath;

  if (
    athValue !== undefined &&
    typeof athValue !== "string"
  ) {
    rejectClaims(
      "ath presente, mas inválido",
      diagnostic,
    );
  }

  const claims: DpopClaims = {
    jti,
    iat,
    htm,
    htu,
  };

  if (typeof athValue === "string") {
    claims.ath = athValue;
  }

  return claims;
}

export async function okpJwkThumbprint(
  jwk: OkpPublicJwk,
): Promise<string> {
  const canonical = JSON.stringify({
    crv: jwk.crv,
    kty: jwk.kty,
    x: jwk.x,
  });

  return sha256Base64Url(utf8(canonical));
}

export async function verifyDpopProof(input: {
  proof: string;
  method: string;
  url: string;
  expectedJkt: string;
  expectedPublicJwk?: OkpPublicJwk;
  accessToken?: string;
  maxAgeSeconds?: number;
}): Promise<{
  jti: string;
  jkt: string;
  iat: number;
}> {
  if (input.proof.length > 16 * 1024) {
    throw new Error("Prova DPoP demasiado grande");
  }

  const parts = input.proof.split(".");

  if (parts.length !== 3) {
    throw new Error("Prova DPoP inválida");
  }

  const [
    protectedPart,
    payloadPart,
    signaturePart,
  ] = parts;

  if (
    !protectedPart ||
    !payloadPart ||
    !signaturePart
  ) {
    throw new Error("Prova DPoP incompleta");
  }

  const header =
    parseBase64UrlJson<Partial<DpopHeader>>(
      protectedPart,
    );

  if (
    header.typ !== "dpop+jwt" ||
    header.alg !== "EdDSA" ||
    !header.jwk
  ) {
    throw new Error("Cabeçalho DPoP inválido");
  }

  const publicJwk = publicOnlyJwk(
    parseOkpJwk(header.jwk, "Ed25519", false),
  );

  const jkt = await okpJwkThumbprint(publicJwk);

  if (jkt !== input.expectedJkt) {
    throw new Error(
      "Chave DPoP não corresponde à sessão",
    );
  }

  if (
    input.expectedPublicJwk &&
    input.expectedPublicJwk.x !== publicJwk.x
  ) {
    throw new Error(
      "Chave DPoP não corresponde ao dispositivo",
    );
  }

  const key = await crypto.subtle.importKey(
    "jwk",
    publicJwk,
    { name: "Ed25519" },
    false,
    ["verify"],
  );

  const valid = await crypto.subtle.verify(
    "Ed25519",
    key,
    base64UrlDecode(signaturePart),
    utf8(`${protectedPart}.${payloadPart}`),
  );

  if (!valid) {
    throw new Error("Assinatura DPoP inválida");
  }

  const rawClaims = JSON.parse(
    decodeUtf8(base64UrlDecode(payloadPart)),
  ) as unknown;

  const claims = validateDpopClaims({
    rawClaims,
    method: input.method,
    url: input.url,
    maxAgeSeconds:
      input.maxAgeSeconds ?? 300,
  });

  if (input.accessToken) {
    const expectedAth = await sha256Base64Url(
      utf8(input.accessToken),
    );

    if (claims.ath !== expectedAth) {
      console.warn("Diagnóstico DPoP", {
        reason:
          "ath diferente do access token",
        receivedAth: claims.ath,
        expectedAth,
      });

      throw new Error("ath DPoP inválido");
    }
  } else if (claims.ath !== undefined) {
    console.warn("Diagnóstico DPoP", {
      reason:
        "ath presente sem access token esperado",
    });

    throw new Error(
      "ath não esperado na prova DPoP",
    );
  }

  return {
    jti: claims.jti,
    jkt,
    iat: claims.iat,
  };
}
