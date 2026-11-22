{ config, lib, ... }:
{
  services.grafana.provision.alerting = {
    contactPoints.settings = {
      apiVersion = 1;
      contactPoints = [{
        orgId = 1;
        name = "matrix";
        receivers = [{
          uid = "matrix-sirenhead";
          type = "webhook";
          settings = {
            url = "http://${lib.head config.services.python-http-handlers.sirenhead.listenStreams}/";
            httpMethod = "POST";
          };
        }];
      }];
    };

    policies.settings = {
      apiVersion = 1;
      policies = [{
        orgId = 1;
        receiver = "matrix";
        group_by = [ "grafana_folder" "alertname" ];
        group_wait = "1m";
        group_interval = "30s";
        repeat_interval = "12h";
        routes = [{
          object_matchers = [[ "notify" "=" "once" ]];
          # I think grafana has no way to say "never repeat", so
          # we just set a big ass eternity here.
          repeat_interval = "999w";
        }];
      }];
    };
  };
}
