# EarnApp Docker
### Docker Image for [EarnApp](https://earnapp.com)

## Clone
```BASH
git clone https://github.com/fazalfarhan01/earnapp_docker.git
```

## Available Tags
1. `latest` - Built and updated daily
2. `hourly-latest` - Built and updated every hour at UTC 10th minute.
3. `lite` - Use when you have problems with regular version.
**Note**: `lite` version cannot generate it's own UUID and the same has to be provided as an environment variable.

## How to:
### _Non Compose_
1. Make a directory for earnapp data
    - `mkdir $HOME/earnapp-data`
2. Run the container
    - `docker run -d --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v $HOME/earnapp-data:/etc/earnapp --name earnapp fazalfarhan01/earnapp`
    
    or if you are using the `lite` version
    - `docker run -d -e EARNAPP_UUID='sdk-node-XXXXXXXXXXXXXXXXXXX'  --name earnapp fazalfarhan01/earnapp:lite`
3. Get the UUID
    - `docker exec -it earnapp showid`
4. Copy and paste the app `UUID` in the [EarnApp Dashboard](https://earnapp.com/dashboard)

### _Running without Docker (bare metal)_
The repository now includes a small helper script for Debian and BusyBox style systems where Docker or systemd may not be available.

1. Copy the installer to your machine and run it as root:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/fazalfarhan01/earnapp_docker/work/scripts/host-install.sh -o /tmp/host-install.sh
   sh /tmp/host-install.sh
   ```
   Set `EARNAPP_UUID` in the environment beforehand if you already have a node ID:
   ```bash
   EARNAPP_UUID=sdk-node-XXXXXXXXXXXXXXXXXXX sh /tmp/host-install.sh
   ```
2. If `systemd` is available the script installs and starts a persistent `earnapp.service`. On BusyBox or other non-systemd hosts it creates `/usr/local/bin/earnapp-daemon`; start it manually (for example `nohup /usr/local/bin/earnapp-daemon >/var/log/earnapp.log 2>&1 &`).
3. If you did not provide a UUID, run `earnapp showid` after installation and register that ID in the [EarnApp Dashboard](https://earnapp.com/dashboard).

### Compose
1. Make a new directory, create a file named `docker-compose.yml` and paste the following into it.
```YML
version: '3.3'
services:
    app:
        image: fazalfarhan01/earnapp
        privileged: true
        volumes:
            - /sys/fs/cgroup:/sys/fs/cgroup:ro
            - ./etc:/etc/earnapp
```

Use the `lite` version if you don't want to run the container priviledged or having any of the issues [here](https://github.com/fazalfarhan01/EarnApp-Docker/issues/2).

```YML
version: '3.3'
services:
    app:
        image: fazalfarhan01/earnapp:lite
        environment:
            EARNAPP_UUID: YOUR_NODE_ID_HERE
```

2. Run `docker-compose up -d`

3. You can access the earnapp cli using the command
    ```BASH
    docker-compose exec app earnapp <YOUR COMMAND GOES HERE>
    ```

## Like my work?
Consider donating.
- BTC: 1PdUFXmVUxy88NRPJ2RFuhyjUqMiJyZybR
- ETH: 0x715810d3619b6831b3d4ff0465ec3523aceb20c6
- PayPal: [@fazalfarhan01](https://www.paypal.me/fazalfarhan01)

## Running without Docker or systemd
For minimal hosts (BusyBox, bare Debian chroots, etc.) where running the container or
systemd is not an option, you can use the provided `scripts/earnapp-standalone.sh`
helper to download the EarnApp binary and keep it running in a simple restart loop.

1. Copy the script to the target system and make it executable:
   ```sh
   chmod +x scripts/earnapp-standalone.sh
   ```
2. (Optional) Set `EARNAPP_UUID` before starting if you already have a node ID. The
   script will write it to `/etc/earnapp/uuid` for you.
3. Run the script as root (it installs the binary to `/usr/local/bin/earnapp` by
   default) and keep it attached to your init system or a `nohup`/`screen` session:
   ```sh
   EARNAPP_UUID=sdk-node-XXXXXXXXXXXXXXXXXXX ./scripts/earnapp-standalone.sh
   ```

### Script defaults and overrides
- Data directory: `/etc/earnapp` (override with `EARNAPP_DATA`)
- Binary location: `/usr/local/bin/earnapp` (override with `EARNAPP_BIN`)
- Log file: `/etc/earnapp/earnapp.log` (override with `EARNAPP_LOG`)
- Restart delay: 30 seconds between retries (override with `EARNAPP_RESTART_DELAY`)
- Download source/version: defaults to EarnApp CDN version `1.585.464` (override with `EARNAPP_BASE_URL`/`EARNAPP_VERSION`)
- Product detection: auto-picks `piggybox` if `/etc/earnapp/ver_conf.json` contains piggy config (override with `EARNAPP_PRODUCT`)

The script keeps `earnapp run` alive, automatically restarts it if it exits, and writes
basic restart messages to the log file.
