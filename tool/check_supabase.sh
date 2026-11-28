#!/usr/bin/env bash
# Cek koneksi app SpotKerja ke Supabase, memakai kunci di env.json.
# Pemakaian (dari root project):  bash tool/check_supabase.sh
#
# Yang dicek (persis seperti yang dilakukan app):
#   1. env.json terisi
#   2. app boleh MEMBACA spot, review, profil
#   3. app TIDAK boleh menulis review tanpa login (harus ditolak)
#   4. login Google aktif

set -u
cd "$(dirname "$0")/.." || exit 1

ok()   { printf "  ✅ %s\n" "$1"; }
fail() { printf "  ❌ %s\n" "$1"; FAILED=1; }
FAILED=0

if [ ! -f env.json ]; then
  echo "❌ env.json belum ada. Jalankan: cp env.example.json env.json lalu isi."
  exit 1
fi

read_json() { python3 -c "import json,sys; print(json.load(open('env.json')).get('$1','').rstrip('/'))"; }
URL=$(read_json SUPABASE_URL)
KEY=$(read_json SUPABASE_PUBLISHABLE_KEY)

echo "1. env.json"
if [[ "$URL" == https://*.supabase.co && "$URL" != *ISI-* ]]; then ok "SUPABASE_URL terisi"; else fail "SUPABASE_URL belum benar"; fi
if [[ -n "$KEY" && "$KEY" != *ISI-* ]]; then ok "SUPABASE_PUBLISHABLE_KEY terisi"; else fail "SUPABASE_PUBLISHABLE_KEY belum diisi"; fi
[ "$FAILED" = 1 ] && exit 1

# request PATH [METHOD] [DATA] -> kode HTTP di $CODE, isi respons di $BODY
CODE=""; BODY=""
request() {
  local path=$1 method=${2:-GET} data=${3:-}
  local tmp; tmp=$(mktemp)
  CODE=$(curl -s -o "$tmp" -w "%{http_code}" -X "$method" \
    -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
    -H "Content-Type: application/json" ${data:+-d "$data"} "$URL$path")
  BODY=$(head -c 300 "$tmp"); rm -f "$tmp"
}

echo "2. Membaca data (harus BERHASIL)"
for table in spots_view reviews profiles; do
  request "/rest/v1/$table?select=id&limit=1"; code=$CODE
  if [ "$code" = 200 ]; then
    ok "$table bisa dibaca"
  elif [[ "$BODY" == *42501* ]]; then
    fail "$table ditolak: izin belum diberikan (jalankan supabase/migrations/20261128010000_grants.sql)"
  elif [[ "$BODY" == *42P01* || "$BODY" == *PGRST205* ]]; then
    fail "$table tidak ditemukan (jalankan supabase/migrations/20261128000000_init.sql)"
  else
    fail "$table gagal: HTTP $code $BODY"
  fi
done

COUNT=$(curl -s -H "apikey: $KEY" -H "Authorization: Bearer $KEY" -H "Prefer: count=exact" \
  -H "Range: 0-0" -o /dev/null -D - "$URL/rest/v1/spots_view?select=id" |
  tr -d '\r' | awk -F/ 'tolower($0) ~ /^content-range/ {print $2}')
[ -n "$COUNT" ] && echo "     (jumlah spot di database: $COUNT)"

echo "3. Menulis review tanpa login (harus DITOLAK)"
request "/rest/v1/reviews" POST \
  '{"spot_id":"00000000-0000-0000-0000-000000000000","wifi":5,"power":5,"quiet":5,"comfort":5,"crowd":"sepi"}'
code=$CODE
if [[ "$code" =~ ^(401|403)$ ]]; then ok "ditolak dengan benar (HTTP $code)"; else fail "TIDAK ditolak (HTTP $code), periksa RLS"; fi

echo "4. Login Google"
GOOGLE=$(curl -s -H "apikey: $KEY" "$URL/auth/v1/settings" |
  python3 -c "import json,sys; print(json.load(sys.stdin).get('external',{}).get('google'))" 2>/dev/null)
if [ "$GOOGLE" = True ]; then ok "provider Google aktif"; else fail "provider Google belum aktif"; fi

echo
if [ "$FAILED" = 0 ]; then
  echo "🎉 Semua beres. App siap dijalankan dengan Supabase."
else
  echo "Masih ada yang perlu dibereskan (lihat tanda ❌ di atas)."
  exit 1
fi
