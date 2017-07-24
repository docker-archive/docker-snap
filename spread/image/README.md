# Generate user password

You can generate the password for the system user assertion via

```
 $ python3 -c 'import crypt; print(crypt.crypt("test", crypt.mksalt(crypt.METHOD_SHA512)))'
```
