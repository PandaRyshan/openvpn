# README

Provide a way to deploy the latest version of OpenVPN using Docker.

## Usage

### Start Server

(Optional) You can use a `.env` file or add `environment` option into `docker-compose.yaml` to set `PROTO` and `DOMAIN`.

* For `PROTO`, `tcp` is the default protocol to avoid some potential udp restrictions
* For `DOMAIN`, container will automatically use your **public IP** to generate base client configs by default if `DOMAIN` is not set

`.env`:

```env
DOMAIN=vpn.example.com
PROTO=udp
```

`docker-compose.yaml`:

```docker-compose.yaml
...
environment:
  - DOMAIN=vpn.example.com
  - PROTO=udp
...
```

Before start the container you can provide a server config `server.conf` and all the certificates in `server` folder if you want, otherwise the container will generate these by default.

Startup the container:

```shell
docker compose up -d
```

### Generate client config file

The config file you generated by default will be named as `<some-random-string>.ovpn`. If you want to specify the client name, you can add the name behind the cmd, and the config file will be named `<specific-name>.ovpn`.

```shell
docker exec openvpn clientgen <specific-name>
```

You can find the clients configurations in `client` folder. You need to download your client config by sftp or copy the content in it and paste into a .ovpn file on your localhost, and import the .ovpn file as the openvpn client config and connect to the server.

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

## Reference

* [Manual for OpenVPN 2.6](https://openvpn.net/community-resources/reference-manual-for-openvpn-2-6/)
* [OpenVPN How-To](https://community.openvpn.net/openvpn/wiki/GettingStartedwithOVPN)
* [Easy-RSA for OpenVPN How-To](https://community.openvpn.net/openvpn/wiki/EasyRSA3-OpenVPN-Howto)
