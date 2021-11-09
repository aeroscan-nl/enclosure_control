Enclosure Control
=================

This is a tool to map disk drives to their enclosures and slots. It exposes the information in a little web interface.

Easily locate which drive is in which slot in your NAS chassis.

It has been tested to work with SuperMicro chassis, notable with LSI backplanes.

Dependencies
------------

Dependencies are ruby, ruby-dev, ruby-bundler and build-essential and SCSI tools `lsscsci` and `sg3-utils`.

Running
------

*WARNING Please make sure your machine is properly firewalled and you have inspected the script for its security properties before running*

To run execute the following as a privileged (needs access to `/etc`, `/sys` and `/dev` to read drive information):

```
bundle install
bundle exec ruby app.rb
```

The service will start on port 4567.

The locate button doesn't work on some older enclosures it seems.

