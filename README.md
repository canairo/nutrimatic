### how to install this beautiful software w/ uv

# make python env

```
uv venv --python=3.13
source .venv/bin/activate
uv pip install conan cmake
```

# install library dependencies

```c
sudo apt-get install libfst-dev libtre-dev libxml2-dev
```

### use meson

```
cd source
meson setup builddir
meson compile -C builddir
```

your binaries should now be in builddir, hooray
