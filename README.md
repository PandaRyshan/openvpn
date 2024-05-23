# README

Provide a way to deploy the latest version of OpenVPN using Docker.

## Usage

### Server

You can use a `.env` file or add `environment` option into `docker-compose.yml`, to set `DOMAIN` and `PROTO`:

```env
DOMAIN=vpn.example.com
PROTO=udp
```

```docker-compose.yml
...
environment:
  - DOMAIN=vpn.example.com
  - PROTO=udp
...
```

To this image, `tcp` is the default protocol, and if you don't provide a domain name, then will use your public ip as the remote host.

Then up the container and network:

```shell
docker compose up -d
```

Generate a new client config, and if you want to specific the client name, you can add the name behind the cmd, and the config file will be named `client-somename.ovpn`, otherwise, it will be a random string.

```shell
docker exec openvpn /build-client.sh <specific-client-name>
```

### Client

You can find server configuration in `server` folder and the clients configurations in `client` folder. This image will generate a new client config file named `client-<random-string>.ovpn` by default. You need to download it by sftp or copy the content in it and paste into a .ovpn file on your localhost, and import the .ovpn file as the openvpn client config and connect to the server.

### IPv6 support

Make sure your docker service has been enabled IPv6 support, if not yet, you could add config below into your docker daemon settings `/etc/docker/daemon.json`:

```json
{
  "experimental": true,
  "ip6tables": true
}
```

Then restart your docker service:

```shell
sudo systemctl restart docker.service
```

## TODO

* [x] build docker image
* [x] cert & config file generator
* [x] client ovpn file generator
* [ ] add radius plugin support
