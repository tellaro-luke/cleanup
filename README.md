# cleanup
A simple and unfeatured bash script &amp; crontab to remove the oldest files in a directory given a desired % threashold to maintain. Intended to be used with Security Onion sensors to replace the iffy clearing mechanism(s) for /nsm/zeek/logs.

1. Clone the repository in /opt:
```
cd /opt
git clone https://github.com/tellaro-luke/cleanup.git
```
2. Set up the crontab: `sudo crontab -e`

```
# From https://github.com/tellaro-luke/cleanup
*/1 * * * * /usr/bin/flock -n /tmp/cleanup.sh.lock /opt/cleanup/cleanup.sh
```
---
Optionally, log the output somewhere. Log output is not optimized for SIEM ingestion.
```
# From https://github.com/tellaro-luke/cleanup
*/1 * * * * /usr/bin/flock -n /tmp/cleanup.sh.lock /opt/cleanup/cleanup.sh > /var/log/cleanup.sh.log
```
You'll also probably want to set up logrotate for this log file: `sudo vim /etc/logrotate.d/cleanup.sh`
```
/var/log/cleanup.sh.log {
    size 10M
    rotate 4
    compress
    missingok
    notifempty
    copytruncate
}
```
