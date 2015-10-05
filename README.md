# fec-proxy

Reverse proxy app to combine multiple applications.

## Configure

Set the `PROXIES` environment variable to a JSON object mapping proxy routes to URLs:

    cf set-env fec-proxy PROXIES='{"/": "https://app1.18f.gov", "/app2": "https://app1.18f.gov"}'

## Deploy

Install autopilot:

    go get github.com/concourse/autopilot
    cf install-plugin $GOPATH/bin/autopilot

Deploy:

    cf zero-downtime-push fec-proxy -f manifest.yml

## Notes

**fec-proxy** uses the openresty nginx bundle for extras like HMAC signing. The bundled `nginx.tgz` file was built under trusty64 using vagrant.
