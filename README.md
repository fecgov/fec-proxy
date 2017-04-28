# fec-proxy

Reverse proxy app to combine multiple applications and redirect rules to create a smooth transition for when beta.fec.gov becomes fec.gov.

## Configure

Set the `PROXIES` environment variable to a JSON object mapping proxy routes to URLs:

    cf set-env fec-proxy PROXIES='{"/": "https://app1.18f.gov", "/app2": "https://app1.18f.gov"}'

## Deploy

Install autopilot:

    go get github.com/concourse/autopilot
    cf install-plugin $GOPATH/bin/autopilot

Deploy to desired space:

    cf target -s space
    cf zero-downtime-push proxy -f manifest_space.yml
