<h1 align="center">
  <img src="https://github.com/user-attachments/assets/977000e9-0f8c-466d-8388-719b2877c425" alt="[Project]" width=50%>
  <br />
  OpenTelemetry Collector
</h1>



<p align="center"><b>This is the snap for <a href="https://opentelemetry.io/docs/collector/">OpenTelemetry Collector</a></b>, <i>a vendor-agnostic way to receive, process and export telemetry data.</i>. It works on Ubuntu, Fedora, Debian, and other major Linux
distributions.</p>

<!-- Uncomment and modify this when you are provided a build status badge
<p align="center">
<a href="https://snapcraft.io/my-snap-name">
  <img alt="enpass" src="https://snapcraft.io/my-snap-name/badge.svg" />
</a>
<a href="https://snapcraft.io/my-snap-name">
  <img alt="enpass" src="https://snapcraft.io/my-snap-name/trending.svg?name=0" />
</a>
</p>
-->

<!-- Uncomment and modify this when you have a screenshot
![my-snap-name](screenshot.png?raw=true "my-snap-name")
-->

<p align="center">Published for <img src="https://raw.githubusercontent.com/anythingcodes/slack-emoji-for-techies/gh-pages/emoji/tux.png" align="top" width="24" /> with 💝 by The Canonical Observability Team</p>

## Install

    sudo snap install opentelemetry-collector

<!-- Uncomment and modify this when your snap is available on the store
[![Get it from the Snap Store](https://snapcraft.io/static/images/badges/en/snap-store-white.svg)](https://snapcraft.io/my-snap-name)
-->

([Don't have snapd installed?](https://snapcraft.io/docs/core/install))



## Configuration

Once installed, a default configuration file will be created at `/snap/opentelemetry-collector/etc/config.yaml`. The snap will try to use all configuration files under the `/etc/otelcol/config.d` folder, in alphabetical order. If none is present, it will use the default config file.

To write a configuration file to suit you needs, consult the [official documentation](https://opentelemetry.io/docs/collector/).


## Enable feature gates

Feature gates can be enabled using the `feature-gates` configuration options with this snap. 
To specify multiple collectors, use a quoted string with comma-separated values. For example:

> sudo snap set node-exporter feature-gates=confighttp.framedSnappy
> sudo snap set node-exporter feature-gates="confighttp.framedSnappy,exporter.kafkaexporter.UseFranzGo"

To explicitly disable a feature gate, prefix the gate name with a `-` symbol:

> sudo snap set node-exporter feature-gates="confighttp.framedSnappy,-exporter.kafkaexporter.UseFranzGo"

Reference the prometheus/node_exporter README.md for the list of collectors enabled by default.

