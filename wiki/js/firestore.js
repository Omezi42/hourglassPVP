// 公開用の集計 public_stats/ を Firestore の REST で認証なしに読む(Architecture.md 10.21節)。
const PROJECT_ID = "hourglasspvp";
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/public_stats/`;
// URL に ?sample を付けると、build_wiki.py --sample で同梱した手元の JSON を読む。
const USE_SAMPLE = new URLSearchParams(location.search).has("sample");

export function decode(value) {
  if ("mapValue" in value) return decodeFields(value.mapValue.fields || {});
  if ("arrayValue" in value) return (value.arrayValue.values || []).map(decode);
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return Number(value.doubleValue);
  if ("stringValue" in value) return value.stringValue;
  if ("booleanValue" in value) return value.booleanValue;
  return null;
}

function decodeFields(fields) {
  const result = {};
  for (const [key, value] of Object.entries(fields)) result[key] = decode(value);
  return result;
}

const cache = new Map();

export function readPublicStats(docId) {
  if (!cache.has(docId)) cache.set(docId, fetchDoc(docId));
  return cache.get(docId);
}

async function fetchDoc(docId) {
  const response = await fetch(USE_SAMPLE ? `sample/${docId}.json` : BASE + docId);
  if (response.status === 404) return null;
  if (!response.ok) throw new Error(`public_stats/${docId}: ${response.status}`);
  const body = await response.json();
  return USE_SAMPLE ? body : decodeFields(body.fields || {});
}
