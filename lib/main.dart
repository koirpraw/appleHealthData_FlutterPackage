import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter/material.dart';
import 'package:health/health.dart';

void main() => runApp(HealthApp());

class HealthApp extends StatefulWidget {
  @override
  _HealthAppState createState() => _HealthAppState();
}

enum AppState {
  DATA_NOT_FETCHED,
  FETCHING_DATA,
  DATA_READY,
  NO_DATA,
  AUTH_NOT_GRANTED,
  DATA_ADDED,
  DATA_NOT_ADDED,
  STEPS_READY,
}

class _HealthAppState extends State<HealthApp> {
  List<HealthDataPoint> _healthDataList = [];
  AppState _state = AppState.DATA_NOT_FETCHED;
  int _nofSteps = 10;
  int _noofStepsWeekly = 10;
  int _noofStepsMonthly = 10;
  double _mgdl = 10.0;

  // create a HealthFactory for use in the app
  HealthFactory health = HealthFactory();

  /// Fetch data points from the health plugin and show them in the app.
  ///

  Future fetchData() async {
    setState(() => _state = AppState.FETCHING_DATA);

    // define the types to get
    final types = [
      HealthDataType.STEPS,
      HealthDataType.WEIGHT,
      HealthDataType.HEIGHT,
      HealthDataType.BLOOD_GLUCOSE,
      HealthDataType.WORKOUT,
      HealthDataType.SLEEP_IN_BED
      // Uncomment these lines on iOS - only available on iOS
      // HealthDataType.AUDIOGRAM
    ];

    // with coresponsing permissions
    final permissions = [
      HealthDataAccess.READ,
      HealthDataAccess.READ,
      HealthDataAccess.READ,
      HealthDataAccess.READ,
      HealthDataAccess.READ,
      HealthDataAccess.READ
      // HealthDataAccess.READ,
    ];

    // get data within the last 24 hours
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));
    final twodaysago = now.subtract(Duration(days: 3));
    // requesting access to the data types before reading them
    // note that strictly speaking, the [permissions] are not
    // needed, since we only want READ access.
    bool requested =
        await health.requestAuthorization(types, permissions: permissions);
    print('requested: $requested');

    // If we are trying to read Step Count, Workout, Sleep or other data that requires
    // the ACTIVITY_RECOGNITION permission, we need to request the permission first.
    // This requires a special request authorization call.
    //
    // The location permission is requested for Workouts using the Distance information.
    await Permission.activityRecognition.request();
    await Permission.location.request();

    if (requested) {
      try {
        // fetch health data
        List<HealthDataPoint> healthData =
            await health.getHealthDataFromTypes(twodaysago, now, types);
        // save all the new data points (only the first 100)
        _healthDataList.addAll((healthData.length < 100)
            ? healthData
            : healthData.sublist(0, 100));
      } catch (error) {
        print("Exception in getHealthDataFromTypes: $error");
      }

      // filter out duplicates
      _healthDataList = HealthFactory.removeDuplicates(_healthDataList);

      // print the results
      _healthDataList.forEach((x) => print(x));

      // update the UI to display the results
      setState(() {
        _state =
            _healthDataList.isEmpty ? AppState.NO_DATA : AppState.DATA_READY;
      });
    } else {
      print("Authorization not granted");
      setState(() => _state = AppState.DATA_NOT_FETCHED);
    }
  }

  /// Add some random health data.
  // Future addData() async {
  //   final now = DateTime.now();
  //   final earlier = now.subtract(Duration(minutes: 20));
  //
  //   final types = [
  //     HealthDataType.STEPS,
  //     HealthDataType.HEIGHT,
  //     HealthDataType.BLOOD_GLUCOSE,
  //     HealthDataType.WORKOUT, // Requires Google Fit on Android
  //     // Uncomment these lines on iOS - only available on iOS
  //     // HealthDataType.AUDIOGRAM,
  //   ];
  //   final rights = [
  //     HealthDataAccess.WRITE,
  //     HealthDataAccess.WRITE,
  //     HealthDataAccess.WRITE,
  //     HealthDataAccess.WRITE,
  //     // HealthDataAccess.WRITE
  //   ];
  //   final permissions = [
  //     HealthDataAccess.READ_WRITE,
  //     HealthDataAccess.READ_WRITE,
  //     HealthDataAccess.READ_WRITE,
  //     HealthDataAccess.READ_WRITE,
  //     // HealthDataAccess.READ_WRITE,
  //   ];
  //   late bool perm;
  //   bool? hasPermissions =
  //   await HealthFactory.hasPermissions(types, permissions: rights);
  //   if (hasPermissions == false) {
  //     perm = await health.requestAuthorization(types, permissions: permissions);
  //   }
  //
  //   // Store a count of steps taken
  //   _nofSteps = Random().nextInt(10);
  //   bool success = await health.writeHealthData(
  //       _nofSteps.toDouble(), HealthDataType.STEPS, earlier, now);
  //
  //   // Store a height
  //   success &=
  //   await health.writeHealthData(1.93, HealthDataType.HEIGHT, earlier, now);
  //
  //   // Store a Blood Glucose measurement
  //   _mgdl = Random().nextInt(10) * 1.0;
  //   success &= await health.writeHealthData(
  //       _mgdl, HealthDataType.BLOOD_GLUCOSE, now, now);
  //
  //   // Store a workout eg. running
  //   success &= await health.writeWorkoutData(
  //     HealthWorkoutActivityType.RUNNING, earlier, now,
  //     // The following are optional parameters
  //     // and the UNITS are functional on iOS ONLY!
  //     totalEnergyBurned: 230,
  //     totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
  //     totalDistance: 1234,
  //     totalDistanceUnit: HealthDataUnit.FOOT,
  //   );
  //
  //   // Store an Audiogram
  //   // Uncomment these on iOS - only available on iOS
  //   // const frequencies = [125.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0];
  //   // const leftEarSensitivities = [49.0, 54.0, 89.0, 52.0, 77.0, 35.0];
  //   // const rightEarSensitivities = [76.0, 66.0, 90.0, 22.0, 85.0, 44.5];
  //
  //   // success &= await health.writeAudiogram(
  //   //   frequencies,
  //   //   leftEarSensitivities,
  //   //   rightEarSensitivities,
  //   //   now,
  //   //   now,
  //   //   metadata: {
  //   //     "HKExternalUUID": "uniqueID",
  //   //     "HKDeviceName": "bluetooth headphone",
  //   //   },
  //   // );
  //
  //   setState(() {
  //     _state = success ? AppState.DATA_ADDED : AppState.DATA_NOT_ADDED;
  //   });
  // }

  /// Fetch steps from the health plugin and show them in the app.
  Future fetchStepData() async {
    int? steps;
    int? steps_weekly;
    int? steps_monthly;

    // get steps for today (i.e., since midnight)
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime.now().subtract(Duration(days: 1));
    final week = DateTime.now().subtract(Duration(days: 7));
    final month = DateTime.now().subtract(Duration(days: 30));

    bool requested = await health.requestAuthorization([HealthDataType.STEPS]);

    if (requested) {
      try {
        steps = await health.getTotalStepsInInterval(midnight, now);
        steps_weekly = await health.getTotalStepsInInterval(week, now);
        steps_monthly = await health.getTotalStepsInInterval(month, now);
      } catch (error) {
        print("Caught exception in getTotalStepsInInterval: $error");
      }

      print('Total number of steps: $steps');

      setState(() {
        _nofSteps = (steps == null) ? 0 : steps;
        _noofStepsWeekly = (steps_weekly == null) ? 0 : steps_weekly;
        _noofStepsMonthly = (steps_monthly == null) ? 0 : steps_monthly;
        _state = (steps == null) ? AppState.NO_DATA : AppState.STEPS_READY;
      });
    } else {
      print("Authorization not granted - error in authorization");
      setState(() => _state = AppState.DATA_NOT_FETCHED);
    }
  }

  Widget _contentFetchingData() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(
              strokeWidth: 10,
            )),
        Text('Fetching data...')
      ],
    );
  }

  Widget _contentDataReady() {
    return ListView.builder(
        itemCount: _healthDataList.length,
        itemBuilder: (_, index) {
          HealthDataPoint points = _healthDataList[index];
          if (points.value is AudiogramHealthValue) {
            return ListTile(
              title: Text("${points.typeString}: ${points.value}"),
              trailing: Text('${points.unitString}'),
              subtitle: Text('${points.dateFrom} - ${points.dateTo}'),
            );
          }
          if (points.value is WorkoutHealthValue) {
            return ListTile(
              title: Text(
                  "${points.typeString}: ${(points.value as WorkoutHealthValue).totalEnergyBurned} ${(points.value as WorkoutHealthValue).totalEnergyBurnedUnit?.typeToString()}"),
              trailing: Text(
                  '${(points.value as WorkoutHealthValue).workoutActivityType.typeToString()}'),
              subtitle: Text('${points.dateFrom} - ${points.dateTo}'),
            );
          }
          return ListTile(
            title: Text("${points.typeString}: ${points.value}"),
            trailing: Text('${points.unitString}'),
            subtitle: Text('${points.dateFrom} - ${points.dateTo}'),
          );
        });
  }

  Widget _contentNoData() {
    return Text('No Data to show');
  }

  Widget _contentNotFetched() {
    return Column(
      children: [
        Text('Press the download button to fetch data.'),
        Text('Press the plus button to insert some random data.'),
        Text('Press the walking button to get total step count.'),
      ],
      mainAxisAlignment: MainAxisAlignment.center,
    );
  }

  Widget _authorizationNotGranted() {
    return Text('Authorization not given. '
        'For Android please check your OAUTH2 client ID is correct in Google Developer Console. '
        'For iOS check your permissions in Apple Health.');
  }

  Widget _dataAdded() {
    return Text('Data points inserted successfully!');
  }

  Widget _stepsFetched() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        SizedBox(
            height: 100,
            width: 400,
            child: Card(
                child:
                    Center(child: Text('$_nofSteps STEPS in last 24 Hours')))),
        SizedBox(
            height: 100,
            width: 400,
            child: Card(
                child:
                Center(child: Text('$_noofStepsWeekly STEPS in last 1 week')))),
        SizedBox(
            height: 100,
            width: 400,
            child: Card(
                child:
                Center(child: Text('$_noofStepsMonthly STEPS in last one month')))),
      ],
    );
  }

  Widget _dataNotAdded() {
    return Text('Failed to add data');
  }

  Widget _content() {
    if (_state == AppState.DATA_READY)
      return _contentDataReady();
    else if (_state == AppState.NO_DATA)
      return _contentNoData();
    else if (_state == AppState.FETCHING_DATA)
      return _contentFetchingData();
    else if (_state == AppState.AUTH_NOT_GRANTED)
      return _authorizationNotGranted();
    else if (_state == AppState.DATA_ADDED)
      return _dataAdded();
    else if (_state == AppState.STEPS_READY)
      return _stepsFetched();
    else if (_state == AppState.DATA_NOT_ADDED) return _dataNotAdded();

    return _contentNotFetched();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
        home: CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Plum Health'),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: <Widget>[
            CupertinoButton(
                color: Colors.grey.shade400,
                pressedOpacity: 0.4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Enable Apple Health"),
                    Icon(
                      Icons.favorite,
                      color: Colors.redAccent,
                    )
                  ],
                ),
                onPressed: () {
                  fetchData();
                }),
            CupertinoButton(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Add Data"),
                    Icon(Icons.add),
                  ],
                ),
                onPressed: () {
                  // addData();
                }),
            CupertinoButton(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Steps"),
                    Icon(Icons.directions_walk),
                  ],
                ),
                onPressed: () {
                  fetchStepData();
                }),
            SizedBox(
              height: 400,
              width: 400,
              child: Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _content(),
                ),
              ),
            ),
            SizedBox(
              height: 400,
              width: 400,
              child: Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("data type"),
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
