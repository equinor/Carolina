# Use with Dakota 6.13

With version 6.13 of Dakota (possibly some earlier versions also) a different
set of boost libraries is needed: instead of `boost_signals`,
`boost_program_options` should be used.

The Carolina code should be updated to detect the Dakota version, and choose the
right library. Until that is done, the file dakota-6.13.patch can be used to
update the `setup.py` file for use with Dakota 6.13:

git apply dakota-6.13.patch
