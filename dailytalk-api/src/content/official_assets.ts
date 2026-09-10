export type OfficialAssetManifestMetadata = {
  pathId: string;
  packageVersion: number;
  manifestVersion: number;
  sha256: string;
  sizeBytes: number;
  contentType: "application/json";
  downloadPath: string;
  immutable: true;
};

export type OfficialAssetManifest = {
  metadata: OfficialAssetManifestMetadata;
  bytes: Uint8Array;
};

export type OfficialAssetBlobMetadata = {
  sha256: string;
  sizeBytes: number;
  contentType: string;
  immutable: true;
};

export type OfficialAssetBlob = {
  metadata: OfficialAssetBlobMetadata;
  bytes: Uint8Array;
};

export const officialAssetCatalogVersion = 1;

const studentFrFrPhase1V2ManifestBase64 =
  'ewogICJtYW5pZmVzdFZlcnNpb24iOiAxLAogICJwYXRoSWQiOiAic3R1ZGVudC5mci1mci5waGFzZTEiLAogICJwYWNrYWdl' +
  'VmVyc2lvbiI6IDIsCiAgImFzc2V0cyI6IFsKICAgIHsKICAgICAgImFzc2V0SWQiOiAiYXJyaXZhbC52b2NhYnVsYXJ5LTAx' +
  'LmlsbHVzdHJhdGlvbi0wMSIsCiAgICAgICJyZXZpc2lvbklkIjogImFycml2YWwudm9jYWJ1bGFyeS0wMS5yZXZpc2lvbi0w' +
  'MiIsCiAgICAgICJyb2xlIjogImlsbHVzdHJhdGlvbiIsCiAgICAgICJjb250ZW50VHlwZSI6ICJpbWFnZS9wbmciLAogICAg' +
  'ICAic2hhMjU2IjogIjU3MmZiMWIwOTNjOTIxNDA4OGY4M2VkYjcwNTg1OWI2NWM1MzFkMzZlMzNmNGQ4ZGYxNjU5NmMxYjYx' +
  'NDg1OGEiLAogICAgICAic2l6ZUJ5dGVzIjogMTc5LAogICAgICAiZG93bmxvYWRQYXRoIjogIi9hcGkvY29udGVudC9hc3Nl' +
  'dHMvYmxvYnMvNTcyZmIxYjA5M2M5MjE0MDg4ZjgzZWRiNzA1ODU5YjY1YzUzMWQzNmUzM2Y0ZDhkZjE2NTk2YzFiNjE0ODU4' +
  'YSIsCiAgICAgICJyZXF1aXJlZCI6IHRydWUsCiAgICAgICJzb3J0T3JkZXIiOiAwCiAgICB9LAogICAgewogICAgICAiYXNz' +
  'ZXRJZCI6ICJhcnJpdmFsLnZvY2FidWxhcnktMDEucHJvbnVuY2lhdGlvbi0wMSIsCiAgICAgICJyZXZpc2lvbklkIjogImFy' +
  'cml2YWwudm9jYWJ1bGFyeS0wMS5yZXZpc2lvbi0wMiIsCiAgICAgICJyb2xlIjogInByb251bmNpYXRpb24iLAogICAgICAi' +
  'Y29udGVudFR5cGUiOiAiYXVkaW8vd2F2IiwKICAgICAgInNoYTI1NiI6ICI5ZGMzZjZjMGE2YzBiOGI3ZWNiYWQzMGRiNDE1' +
  'YzEwY2ZmOGU1MDRkYjk4ODE0NWFkNzRhZmQwZTkyN2M5YjRjIiwKICAgICAgInNpemVCeXRlcyI6IDQwNDQsCiAgICAgICJk' +
  'b3dubG9hZFBhdGgiOiAiL2FwaS9jb250ZW50L2Fzc2V0cy9ibG9icy85ZGMzZjZjMGE2YzBiOGI3ZWNiYWQzMGRiNDE1YzEw' +
  'Y2ZmOGU1MDRkYjk4ODE0NWFkNzRhZmQwZTkyN2M5YjRjIiwKICAgICAgInJlcXVpcmVkIjogdHJ1ZSwKICAgICAgInNvcnRP' +
  'cmRlciI6IDEKICAgIH0KICBdCn0K';

const arrivalVocabularyIllustrationBase64 =
  'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAeklEQVR42mP4+uMXTRHDqAWjFmAgrYoTNLQAaDoE0cQCuOkk' +
  '2cFAnunE28FAtulE2sFAienE2MFAoekE7WCg3HT8djBQxXQ8djDgMf3162fEI1x24AsikiwgJw7oZEHUltcQNGoBMXGQF2AO' +
  'R6MWjFowKCwYbXjRxwIAzhXEtrL82OQAAAAASUVORK5CYII=';

const arrivalVocabularyPronunciationBase64 =
  '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' +
  '9uNm4JLgduSb6yr1';

const studentFrFrPhase1V2ManifestMetadata: OfficialAssetManifestMetadata = {
  pathId: "student.fr-fr.phase1",
  packageVersion: 2,
  manifestVersion: 1,
  sha256: "d9ac2ce729a71cbacab669bb971c9511e340e0f7a140299ad80d5faee540aac9",
  sizeBytes: 1029,
  contentType: "application/json",
  downloadPath: "/api/content/assets/manifests/student.fr-fr.phase1/2",
  immutable: true,
};

const arrivalVocabularyIllustrationMetadata: OfficialAssetBlobMetadata = {
  sha256: "572fb1b093c9214088f83edb705859b65c531d36e33f4d8df16596c1b614858a",
  sizeBytes: 179,
  contentType: "image/png",
  immutable: true,
};

const arrivalVocabularyPronunciationMetadata: OfficialAssetBlobMetadata = {
  sha256: "9dc3f6c0a6c0b8b7ecbad30db415c10cff8e504db988145ad74afd0e927c9b4c",
  sizeBytes: 4044,
  contentType: "audio/wav",
  immutable: true,
};

function decodeBase64(value: string): Uint8Array {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

const manifests: OfficialAssetManifest[] = [
  {
    metadata: studentFrFrPhase1V2ManifestMetadata,
    bytes: decodeBase64(studentFrFrPhase1V2ManifestBase64),
  },
];

const blobs: OfficialAssetBlob[] = [
  {
    metadata: arrivalVocabularyIllustrationMetadata,
    bytes: decodeBase64(arrivalVocabularyIllustrationBase64),
  },
  {
    metadata: arrivalVocabularyPronunciationMetadata,
    bytes: decodeBase64(arrivalVocabularyPronunciationBase64),
  },
];

export function listLatestOfficialAssetManifests(): OfficialAssetManifestMetadata[] {
  const latestByPath = new Map<string, OfficialAssetManifestMetadata>();
  for (const item of manifests) {
    const current = latestByPath.get(item.metadata.pathId);
    if (!current || item.metadata.packageVersion > current.packageVersion) {
      latestByPath.set(item.metadata.pathId, item.metadata);
    }
  }
  return [...latestByPath.values()]
    .sort((a, b) => a.pathId.localeCompare(b.pathId))
    .map((metadata) => ({ ...metadata }));
}

export function findOfficialAssetManifest(
  pathId: string,
  packageVersion: number,
): OfficialAssetManifest | null {
  const found = manifests.find(
    (item) =>
      item.metadata.pathId === pathId &&
      item.metadata.packageVersion === packageVersion,
  );
  if (!found) return null;
  return {
    metadata: { ...found.metadata },
    bytes: found.bytes.slice(),
  };
}

export function findOfficialAssetBlob(sha256: string): OfficialAssetBlob | null {
  const normalized = sha256.trim().toLowerCase();
  const found = blobs.find((item) => item.metadata.sha256 === normalized);
  if (!found) return null;
  return {
    metadata: { ...found.metadata },
    bytes: found.bytes.slice(),
  };
}

export function officialAssetEtag(sha256: string): string {
  return `"sha256-${sha256}"`;
}
