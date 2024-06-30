# Documentation for the tesla_ble_mqtt packages

...

## How to update "apps":

- when you make changes in _core, it will not affect the "apps". To pull the new code in the apps, you need to `git pull https://github.com/tesla-local-control/tesla_ble_mqtt_core main` then commit your update in the app, (addon or docker), then you can work on the app
- if you want to test the new _core code in addon or docker, you need to:
1/ branch the _core
2/ branch the app
3/ change the _core code
4/ git pull https://github.com/tesla-local-control/tesla_ble_mqtt_core [your _core branch]
- when you are ready to merge:
1/ merge _core into main
2/ `git pull https://github.com/tesla-local-control/tesla_ble_mqtt_core main`
3/ merge your app branch