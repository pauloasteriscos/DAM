const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();

export function utf8(value: string): Uint8Array {
  return textEncoder.encode(value);
}

export function decodeUtf8(value: ArrayBuffer | Uint8Array): string {
  return textDecoder.decode(value);
}

export function base64UrlEncode(value: ArrayBuffer | Uint8Array): string {
  const bytes = value instanceof Uint8Array ? value : new Uint8Array(value);
  let binary = "";

  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

export function base64UrlDecode(value: string): Uint8Array {
  if (!/^[A-Za-z0-9_-]*$/.test(value)) {
    throw new Error("Base64url inválido");
  }

  const padded = value
    .replace(/-/g, "+")
    .replace(/_/g, "/")
    .padEnd(Math.ceil(value.length / 4) * 4, "=");
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);

  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }

  return bytes;
}

export function base64UrlJson(value: unknown): string {
  return base64UrlEncode(utf8(JSON.stringify(value)));
}

export function parseBase64UrlJson<T>(value: string): T {
  return JSON.parse(decodeUtf8(base64UrlDecode(value))) as T;
}

export function concatBytes(...parts: Array<ArrayBuffer | Uint8Array>): Uint8Array {
  const arrays = parts.map((part) =>
    part instanceof Uint8Array ? part : new Uint8Array(part),
  );
  const length = arrays.reduce((total, part) => total + part.length, 0);
  const output = new Uint8Array(length);
  let offset = 0;

  for (const part of arrays) {
    output.set(part, offset);
    offset += part.length;
  }

  return output;
}

export function uint32(value: number): Uint8Array {
  if (!Number.isInteger(value) || value < 0 || value > 0xffffffff) {
    throw new Error("Valor uint32 inválido");
  }

  const output = new Uint8Array(4);
  new DataView(output.buffer).setUint32(0, value, false);
  return output;
}

export function lengthPrefixed(value: Uint8Array): Uint8Array {
  return concatBytes(uint32(value.length), value);
}

export async function sha256(value: Uint8Array): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", value));
}

export async function sha256Base64Url(value: Uint8Array): Promise<string> {
  return base64UrlEncode(await sha256(value));
}

export function randomBase64Url(length: number): string {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return base64UrlEncode(bytes);
}

export function normalizedHtu(rawUrl: string): string {
  const url = new URL(rawUrl);
  return `${url.origin}${url.pathname}`;
}
