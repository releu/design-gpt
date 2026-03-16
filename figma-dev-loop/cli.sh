#!/bin/bash
# Dev loop CLI helper
# Usage: ./cli.sh <command> [args]
#   trigger-run <shareCode>   — trigger a render
#   trigger-inspect <expr>    — trigger an inspect
#   trigger-eval <js>         — trigger an eval
#   result                    — get latest result
#   poll                      — check what plugin would get
#   health                    — server health
#   wait-result [timeout_s]   — poll until result is not pending

BASE="http://localhost:4000"

case "$1" in
  trigger-run)
    curl -s -X POST "$BASE/trigger" -H "Content-Type: application/json" \
      -d "{\"action\":\"run\",\"code\":\"$2\"}"
    ;;
  trigger-inspect)
    curl -s -X POST "$BASE/trigger" -H "Content-Type: application/json" \
      -d "{\"action\":\"inspect\",\"expression\":$(echo "$2" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}"
    ;;
  trigger-eval)
    curl -s -X POST "$BASE/trigger" -H "Content-Type: application/json" \
      -d "{\"action\":\"eval\",\"js\":$(echo "$2" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}"
    ;;
  result)
    curl -s "$BASE/result" | python3 -m json.tool
    ;;
  poll)
    curl -s "$BASE/poll" | python3 -m json.tool
    ;;
  health)
    curl -s "$BASE/health" | python3 -m json.tool
    ;;
  wait-result)
    timeout=${2:-30}
    elapsed=0
    while [ $elapsed -lt $timeout ]; do
      r=$(curl -s "$BASE/result")
      status=$(echo "$r" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null)
      if [ "$status" != "pending" ]; then
        echo "$r" | python3 -m json.tool
        exit 0
      fi
      sleep 2
      elapsed=$((elapsed + 2))
    done
    echo '{"status":"timeout"}'
    ;;
  *)
    echo "Usage: $0 {trigger-run|trigger-inspect|trigger-eval|result|poll|health|wait-result} [args]"
    ;;
esac
