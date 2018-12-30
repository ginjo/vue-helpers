#!/bin/sh

# Runs tests without rake
ruby -Ilib:test test/vue/helpers_test.rb -v
