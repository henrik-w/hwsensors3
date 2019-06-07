#!/bin/bash

# WARNING: DON'T EDIT THIS FILE DIRECTLY!
# if you need different settings just make a copy of this file in your Home directory
# and that last will take the precedence over this one!

export LC_ALL=C

# branchPath store the default branch you want to use.
# branchPath=trunk or branchPath=branches/development
export branchPath=trunk

# PREFERRED_SDK store the default sdk to build kexts. If exist,
# otherwise the latest will be used.
# macosx10.11, macosx10.12 or macosx (latest)
export PREFERRED_SDK="macosx10.11"

# PREFERRED_CONF store the default configuration to build kexts.
# 'Release 10.6', 'Release', 'Debug' etc.
export PREFERRED_CONF='Release 10.6'

# PREFERRED_CONF_APPS store the default configuration to build apps.
export PREFERRED_CONF_APPS='Release'
