import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'MapTypes.dart';

class HomeScreen extends StatefulWidget
{
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
{

  GoogleMapController mapController;
  CameraPosition initialCameraPosition;

  String searchAddress;
  List<Marker> myMarkers = [];

  List<Marker> customMarkers = [];
  List<Circle> customCircles = [];

  bool mapToggle = false;
  var myLocation;

  final key = GlobalKey<FormState>();

  TextEditingController radiusController = TextEditingController();

  MapType myMapType = MapType.normal;


  @override
  void initState()
  {
    super.initState();
    myLocation = Geolocator().getCurrentPosition().then((currentLocation)
    {
      setState(()
      {
        myLocation = currentLocation;
        mapToggle = true;

        initialCameraPosition = CameraPosition(target: LatLng(currentLocation.latitude,
            currentLocation.longitude),zoom: 12);

        myMarkers.add(Marker(markerId: MarkerId(currentLocation.toString()),
            position: LatLng(currentLocation.latitude,currentLocation.longitude)));

      });
    });

    setMarkers();
  }

  setMarkers()
  {
    Firestore.instance.collection('Markers').getDocuments().then((docs)
    {
      if(docs.documents.isNotEmpty)
        {
          for(int i=0;i<docs.documents.length;i++)
            {
              var markerID = docs.documents[i].data['latitude'];
              customMarkers.add(Marker(markerId: MarkerId(markerID.toString()),
                  position: LatLng(docs.documents[i].data['latitude'],docs.documents[i].data['longitude']),
                  onTap: ()
                  {
                    print(' ***** Marker is Tapped .... *****');

                    Firestore.instance.collection('Markers').document(docs.documents[i].documentID).delete();

                    setState(()
                    {
                        customMarkers.removeAt(i);
                        customCircles.removeAt(i);
                    });

                  } ));
              
              customCircles.add(Circle(circleId: CircleId(markerID.toString()),
                  center: LatLng(docs.documents[i].data['latitude'],docs.documents[i].data['longitude']),
                  radius: docs.documents[i].data['radius'] * 1000,fillColor: Color(0x220000FF),
                  strokeWidth: 1,));
            }
        }
    });

  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(

      appBar: AppBar(
        title: Text('Google Map'),
        centerTitle: true,
        actions: <Widget>[

          PopupMenuButton<String>(
            onSelected: ChoiceActions,
            itemBuilder: (BuildContext context)
            {
              return MapTypes.mapTypes.map((String choice)
              {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          )

        ],
      ),

      body: Stack(
        children: <Widget>[

          mapToggle == true
              ? GoogleMap(
                mapType: myMapType,
                initialCameraPosition: initialCameraPosition,
                onMapCreated: onMapCreated,
                markers: Set.from(customMarkers),
                circles: Set.from(customCircles),
                onTap: handleMarkers,
                )
              : Container(color: Colors.grey,child: Center(
                 child: Text('Loading ... Please wait ..',style:
                 TextStyle(fontSize: 20),),)),

          Positioned(
            top: 15,right: 15,left: 15,
            child: Container(
              height: 50,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                color: Colors.white
              ),
              alignment: Alignment.center,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Enter Address',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(top: 14,left: 20,right: 20),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search),
                    onPressed: searchAndNavigate,
                    iconSize: 25,
                  ),
                ),
                onChanged: (val)
                {
                  setState(()
                  {
                      searchAddress = val;
                  });
                },
              ),
            ),
          )

        ],
      ),

    );
  }

  void onMapCreated(GoogleMapController controller)
  {
    setState(()
    {
      mapController = controller;
    });
  }

  void searchAndNavigate()
  {
    Geolocator().placemarkFromAddress(searchAddress).then((result)
    {
      mapController.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(result[0].position.latitude,result[0].position.longitude),zoom: 12)));
    });
  }

  bool validateForm()
  {
    final keys = key.currentState;
    if(keys.validate())
      {
        keys.save();
        return true;
      }
    return false;
  }

  handleMarkers(LatLng tappedPoint)
  {

    double circleRadius;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context)
        {
          return AlertDialog(
            title: Center(child: Text('Alert For Circle',style: TextStyle(fontWeight: FontWeight.bold),)),
            content:  Container(
              height: 150,
              child: Form(
                key: key,
                child: Column(
                  children: <Widget>[

                    SizedBox(height: 20,),

                    Text('Enter Total Radius in Kilometers ... ',style: TextStyle(),),

                    SizedBox(height: 20,),

                    TextFormField(
                      controller: radiusController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Radius in km',
                      ),
                      validator: (value)
                      {
                        return value.isEmpty ? 'Radius Required' : null;
                      },
                    ),

                  ],
                ),
              ),
            ),
            actions: <Widget>[

              FlatButton(
                child: Text('Ok',style: TextStyle(fontSize: 16),),
                onPressed: ()
                {
                  if(validateForm())
                    {
                      circleRadius = double.parse(radiusController.text);

                      double  estimatedRadius = circleRadius * 1000;

                      Map<String,dynamic> data =
                      {
                        'markerId' : tappedPoint.toString(),
                        'latitude' : tappedPoint.latitude,
                        'longitude' : tappedPoint.longitude,
                        'radius' : circleRadius
                      };

                      Firestore.instance.collection('Markers').add(data).catchError((e){print(e.toString());});

                      setState(()
                      {
                        customMarkers.add(Marker(markerId: MarkerId(tappedPoint.toString()),position: tappedPoint));

                        customCircles.add(Circle(circleId: CircleId(tappedPoint.toString()),
                            center: tappedPoint,radius: estimatedRadius,fillColor: Color(0x220000FF),strokeWidth: 1));
                      });

                      Navigator.of(context).pop();
                    }
                },
              ),

              FlatButton(
                child: Text('Cancel',style: TextStyle(fontSize: 16),),
                onPressed: ()
                {
                  Navigator.of(context).pop();
                },
              ),

            ],
          );
        }
    );


  }

  void ChoiceActions(String choice)
  {

    MapType map;

    if(choice == MapTypes.NormalView)
      {
        map = MapType.normal;
      }
    else if(choice == MapTypes.SatelliteView)
      {
        map = MapType.satellite;
      }
    else if(choice == MapTypes.TerrainView)
      {
        map = MapType.terrain;
      }
    else if(choice == MapTypes.DeleteAllPoints)
      {

        Firestore.instance.collection('Markers').getDocuments().then((snapshot)
        {
           for(DocumentSnapshot ds in snapshot.documents)
             {
               ds.reference.delete();
             }
        });

        customCircles.clear();
        customMarkers.clear();
      }

    setState(()
    {
      if(map != null)
        {
          myMapType = map;
        }
    });

  }
}

