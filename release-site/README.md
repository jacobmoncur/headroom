# Headroom release site

Static landing page and binary-release surface for Headroom.

The download buttons target the latest GitHub release asset named `Headroom-0.3.0.dmg`. Publish the notarized DMG before enabling Pages; the link will return 404 until that release exists.

Preview locally with:

```sh
python3 -m http.server 8080 --directory release-site
```
