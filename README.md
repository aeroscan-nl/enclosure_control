Enclosure Control
=================

This is a tool to map disk drives to their enclosures and slots. It exposes the information in a little web interface.

Easily locate which drive is in which slot in your NAS chassis.

It has been tested to work with SuperMicro chassis, notable with LSI backplanes.

Dependencies
------------

Dependencies are ruby, ruby-dev, ruby-bundler and build-essential and SCSI tools `lsscsci` and `sg_map`.

Running
------

*WARNING Please make sure your machine is properly firewalled and you have inspected the script for its security properties before running*

To run execute the following as a privileged (needs access to `/etc`, `/sys` and `/dev` to read drive information):

```
bundle install
bundle exec app.rb
```

The service will start on port 4567.

The locate button doesn't seem to do anything, not sure why maybe it will work for you, but you should get information about
which drive is in which slot at least. Let me know if it works for you by submitting an issue!



