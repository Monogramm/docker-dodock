
ERROR: After October 2020 you may experience errors when installing or updating packages. This is because pip will change the way that it resolves dependency conflicts.
We recommend you use --use-feature=2020-resolver to test your packages with the new resolver before it becomes the default.

# Debian

bench 1.5.1 requires six==1.12.0, but you'll have six 1.13.0 which is incompatible.
frontmatter 3.0.5 requires PyYAML==3.13, but you'll have pyyaml 5.1 which is incompatible.

dodock_socketio          | Unable to join chat room. Error: connect ECONNREFUSED 127.0.0.1:8080

# Alpine

frontmatter 3.0.5 requires PyYAML==3.13, but you'll have pyyaml 5.1 which is incompatible.

pip install numpy==1.17.4; but Collecting numpy>=1.13.3 when setting frappe
Created wheel for numpy: filename=numpy-1.19.4-cp37-cp37m-linux_x86_64.whl
pip install pandas==0.24.2; but Collecting pandas==0.25.3 when setting frappe

    building 'pandas._libs.json' extension
    creating build/temp.linux-x86_64-3.7/pandas/_libs/src/ujson
    creating build/temp.linux-x86_64-3.7/pandas/_libs/src/ujson/python
    creating build/temp.linux-x86_64-3.7/pandas/_libs/src/ujson/lib
    gcc -Wno-unused-result -Wsign-compare -DNDEBUG -g -fwrapv -O3 -Wall -DTHREAD_STACK_SIZE=0x100000 -fPIC -DNPY_NO_DEPRECATED_API=0 -Ipandas/_libs/src/ujson/python -Ipandas/_libs/src/ujson/lib -Ipandas/_libs/src/datetime -I/home/dodock/dodock-bench/env/lib/python3.7/site-packages/numpy/core/include -I/home/dodock/dodock-bench/env/include -I/usr/local/include/python3.7m -c pandas/_libs/src/ujson/python/ujson.c -o build/temp.linux-x86_64-3.7/pandas/_libs/src/ujson/python/ujson.o -D_GNU_SOURCE -Wno-unused-function
    gcc -Wno-unused-result -Wsign-compare -DNDEBUG -g -fwrapv -O3 -Wall -DTHREAD_STACK_SIZE=0x100000 -fPIC -DNPY_NO_DEPRECATED_API=0 -Ipandas/_libs/src/ujson/python -Ipandas/_libs/src/ujson/lib -Ipandas/_libs/src/datetime -I/home/dodock/dodock-bench/env/lib/python3.7/site-packages/numpy/core/include -I/home/dodock/dodock-bench/env/include -I/usr/local/include/python3.7m -c pandas/_libs/src/ujson/python/objToJSON.c -o build/temp.linux-x86_64-3.7/pandas/_libs/src/ujson/python/objToJSON.o -D_GNU_SOURCE -Wno-unused-function
    pandas/_libs/src/ujson/python/objToJSON.c: In function 'initObjToJSON':
    pandas/_libs/src/ujson/python/objToJSON.c:181:12: error: 'NUMPY_IMPORT_ARRAY_RETVAL' undeclared (first use in this function)
      181 |     return NUMPY_IMPORT_ARRAY_RETVAL;
          |            ^~~~~~~~~~~~~~~~~~~~~~~~~
    pandas/_libs/src/ujson/python/objToJSON.c:181:12: note: each undeclared identifier is reported only once for each function it appears in
    pandas/_libs/src/ujson/python/objToJSON.c:182:1: warning: control reaches end of non-void function [-Wreturn-type]
      182 | }
          | ^
    error: command 'gcc' failed with exit status 1

