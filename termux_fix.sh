# Termux DNS workaround
if [ -d /data/data/com.termux ]; then
    export TF_CLI_CONFIG_FILE="$PWD/.terraformrc"
    PROXY_PORT=9080
    if curl -s --max-time 1 -o /dev/null "http://127.0.0.1:${PROXY_PORT}/" 2>/dev/null; then
        :
    elif [ -f "https_proxy.py" ]; then
        python3 https_proxy.py >/dev/null 2>&1 &
        for _ in $(seq 1 10); do
            curl -s --max-time 1 -o /dev/null "http://127.0.0.1:${PROXY_PORT}/" 2>/dev/null && break
            sleep 0.3
        done
        curl -s --max-time 1 -o /dev/null "http://127.0.0.1:${PROXY_PORT}/" 2>/dev/null || { echo "ERROR: proxy failed" >&2; exit 1; }
    else
        echo "ERROR: https_proxy.py not found" >&2; exit 1
    fi
    export HTTP_PROXY="http://127.0.0.1:${PROXY_PORT}"
    export HTTPS_PROXY="http://127.0.0.1:${PROXY_PORT}"
fi
