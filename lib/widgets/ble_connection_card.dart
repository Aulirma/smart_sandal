import 'package:flutter/material.dart';

import '../services/emerys_ble_service.dart';


class BleConnectionCard extends StatefulWidget {

  const BleConnectionCard({
    super.key,
  });


  @override
  State<BleConnectionCard> createState() =>
      _BleConnectionCardState();

}



class _BleConnectionCardState
    extends State<BleConnectionCard> {


  final EmerysBleService ble =
      EmerysBleService.instance;


  bool isLoading = false;



  Future<void> connect() async {

    setState(() {
      isLoading = true;
    });


    try {

      await ble.scanAndConnect();


      setState(() {});


    } catch(e){

      debugPrint(
          "BLE Error : $e"
      );

    }


    setState(() {

      isLoading = false;

    });


  }




  Future<void> disconnect() async {


    await ble.disconnect();


    setState(() {});


  }





  @override
  Widget build(BuildContext context) {


    final connected =
        ble.isConnected;



    return Container(

      width: double.infinity,

      padding:
      const EdgeInsets.all(20),


      decoration:
      BoxDecoration(

        color:
        Theme.of(context)
            .cardColor,


        borderRadius:
        BorderRadius.circular(24),


        boxShadow: [

          BoxShadow(

            color:
            Colors.black
                .withValues(alpha:0.03),

            blurRadius:10,

          )

        ],

      ),



      child: Row(

        children: [


          Container(

            padding:
            const EdgeInsets.all(12),


            decoration:
            BoxDecoration(

              shape:
              BoxShape.circle,


              color:

              connected

                  ? const Color(0xFFDCFCE7)

                  : const Color(0xFFFEE2E2),

            ),


            child:

            Icon(

              Icons.bluetooth,

              color:

              connected

                  ? Colors.green

                  : Colors.red,

            ),

          ),



          const SizedBox(width:16),



          Expanded(

            child: Column(

              crossAxisAlignment:
              CrossAxisAlignment.start,


              children: [


                Text(

                  "EMERYS_001",

                  style:
                  TextStyle(

                    fontWeight:
                    FontWeight.bold,

                    fontSize:15,

                    color:
                    Theme.of(context)
                        .colorScheme
                        .onSurface,

                  ),

                ),



                const SizedBox(height:4),



                Text(

                  connected

                      ? "Menerima data sensor secara langsung"

                      : "Belum terhubung dengan sandal",

                  style:
                  TextStyle(

                    fontSize:12,

                    color:
                    Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,

                  ),

                ),


              ],

            ),

          ),



          const SizedBox(width:10),



          isLoading

              ?

          const SizedBox(

            width:24,

            height:24,

            child:
            CircularProgressIndicator(
              strokeWidth:2,
            ),

          )


              :

          TextButton(

            onPressed:

            connected

                ? disconnect

                : connect,


            child:

            Text(

              connected

                  ? "Putuskan"

                  : "Hubungkan",

              style:

              TextStyle(

                color:

                connected

                    ? Colors.red

                    : const Color(0xFF0D9488),

                fontWeight:
                FontWeight.bold,

              ),

            ),

          )



        ],

      ),


    );


  }


}