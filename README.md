# README

Provide a way to deploy the latest version of OpenVPN using Docker.

## Usage

You can use a **.env** file or add **environment** option into **docker-compose.yml**, to set `DOMAIN` and `PROTO`:

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

## IPv6 support

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
* [ ] add radius plugin support
