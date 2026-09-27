import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch(e) {
    print("Firebase init failed: $e");
  }

class UserAcc {
  String name, email, pass, houseName, phone, address, solarType;
  List<Reading> readings = [];
  UserAcc(this.name, this.email, this.pass, this.houseName, this.phone, this.address, this.solarType);
  Map<String, dynamic> toMap() => {
    'name': name, 'email': email, 'pass': pass, 'houseName': houseName,
    'phone': phone, 'address': address, 'solarType': solarType,
  };
  static UserAcc fromMap(Map<String, dynamic> m) => UserAcc(
    m['name'], m['email'], m['pass'], m['houseName'], m['phone'], m['address'], m['solarType']
  );
}

class Reading {
  double voltage, current, temp, irradiance, actual, expected, perf;
  String status, message;
  List<String> causes;
  String recommendation;
  DateTime time;
  Reading({required this.voltage, required this.current, required this.temp, required this.irradiance, required this.actual, required this.expected, required this.perf, required this.status, required this.message, required this.causes, required this.recommendation, required this.time});
  Map<String, dynamic> toMap() => {
    'voltage': voltage, 'current': current, 'temp': temp, 'irradiance': irradiance,
    'actual': actual, 'expected': expected, 'perf': perf, 'status': status,
    'message': message, 'causes': causes, 'recommendation': recommendation,
    'time': time.toIso8601String()
  };
  static Reading fromMap(Map<String, dynamic> m) => Reading(
    voltage: (m['voltage'] as num).toDouble(), current: (m['current'] as num).toDouble(),
    temp: (m['temp'] as num).toDouble(), irradiance: (m['irradiance'] as num).toDouble(),
    actual: (m['actual'] as num).toDouble(), expected: (m['expected'] as num).toDouble(),
    perf: (m['perf'] as num).toDouble(), status: m['status'], message: m['message'],
    causes: List<String>.from(m['causes']), recommendation: m['recommendation'],
    time: DateTime.parse(m['time'])
  );
}

UserAcc? currentUser;
FirebaseFirestore db = FirebaseFirestore.instance;

Map<String, dynamic> analyzeAI(double actual, double expected, double temp, double irradiance) {
  double perf = expected == 0? 0 : (actual / expected) * 100;
  String status, msg, rec;
  List<String> causes = [];
  if (perf >= 80) { status = "NORMAL"; msg = "Performance is within expected range."; rec = "System is performing normally."; }
  else if (perf >= 50) { status = "WARNING"; msg = "Performance below expected."; rec = "Monitor system and inspect panels."; }
  else { status = "CRITICAL"; msg = "Significant performance drop detected."; rec = "Inspection recommended. Check dust, shading, temperature."; }
  if (perf < 80) { causes.add("Dust accumulation"); causes.add("Shading"); }
  if (temp > 40) causes.add("High temperature");
  if (irradiance < 500) causes.add("Reduced irradiance");
  if (causes.isEmpty) causes.add("No major issues");
  return {"perf": perf, "status": status, "msg": msg, "causes": causes, "rec": rec};
}

class SolarConnectApp extends StatelessWidget {
  @override Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData(primaryColor: Color(0xFF2E7D32), scaffoldBackgroundColor: Color(0xFFF8FAFC)), home: SplashScreen());
  }
}
class SplashScreen extends StatefulWidget { @override _SplashScreenState createState() => _SplashScreenState(); }
class _SplashScreenState extends State<SplashScreen> {
  @override void initState() { super.initState(); Timer(Duration(seconds: 2), () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()))); }
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.white, body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.wb_sunny_rounded, size: 70, color: Colors.orange), Text("SolarConnect", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))), CircularProgressIndicator(color: Color(0xFF2E7D32))])));
  }
}
class RegisterScreen extends StatefulWidget { @override _RegisterScreenState createState() => _RegisterScreenState(); }
class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  String name="", email="", pass="", confirmPass="", house="", phone="", address="", solarType="On-Grid";
  bool _obscurePass = true, _obscureConfirm = true;
  List<String> solarTypes = ["On-Grid", "Off-Grid", "Hybrid"];
  InputDecoration _dec(String label, String hint, {Widget? suffix}) {
    return InputDecoration(labelText: label, hintText: hint, suffixIcon: suffix, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)));
  }
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Color(0xFFF8FAFC), appBar: AppBar(title: Text("Create Account"), backgroundColor: Color(0xFF2E7D32), foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: EdgeInsets.all(20), child: Form(key: _form, child: Column(children: [
        TextFormField(decoration: _dec("Full Name", "Enter full name"), validator: (v)=> v!.isEmpty? "Required": null, onSaved: (v)=> name=v!),
        SizedBox(height: 12),
        TextFormField(decoration: _dec("Email", "Enter email"), validator: (v)=>!v!.contains("@")? "Valid email": null, onSaved: (v)=> email=v!),
        SizedBox(height: 12),
        TextFormField(decoration: _dec("Phone Number", "Mobile number"), keyboardType: TextInputType.phone, validator: (v)=> v!.length<10? "Valid number": null, onSaved: (v)=> phone=v!),
        SizedBox(height: 12),
        TextFormField(decoration: _dec("Address / Location", "House location"), validator: (v)=> v!.isEmpty? "Required": null, onSaved: (v)=> address=v!),
        SizedBox(height: 12),
        DropdownButtonFormField<String>(value: solarType, decoration: _dec("Solar Type", "Select"), items: solarTypes.map((e)=> DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v)=> setState(()=> solarType=v!)),
        SizedBox(height: 12),
        TextFormField(decoration: _dec("House / System Name", "e.g. House 02"), validator: (v)=> v!.isEmpty? "Required": null, onSaved: (v)=> house=v!),
        SizedBox(height: 12),
        TextFormField(decoration: _dec("Password", "Enter password", suffix: IconButton(icon: Icon(_obscurePass? Icons.visibility_off : Icons.visibility), onPressed: ()=> setState(()=> _obscurePass=!_obscurePass))), obscureText: _obscurePass, validator: (v)=> v!.length<6? "Min 6": null, onChanged: (v)=> pass=v, onSaved: (v)=> pass=v!),
        SizedBox(height: 12),
        TextFormField(decoration: _dec("Confirm Password", "Re-enter", suffix: IconButton(icon: Icon(_obscureConfirm? Icons.visibility_off : Icons.visibility), onPressed: ()=> setState(()=> _obscureConfirm=!_obscureConfirm))), obscureText: _obscureConfirm, validator: (v)=> v!=pass? "Not matching": null),
        SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () async {
          if(_form.currentState!.validate()){ _form.currentState!.save();
            var doc = await db.collection('users').doc(email).get();
            if(doc.exists){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Email exists"))); return; }
            UserAcc u = UserAcc(name,email,pass,house,phone,address,solarType);
            await db.collection('users').doc(email).set(u.toMap());
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Account created in Firebase!")));
            Navigator.pop(context);
          }
        }, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF2E7D32)), child: Text("CREATE ACCOUNT", style: TextStyle(color: Colors.white)))),
      ]))),
    );
  }
}
class LoginScreen extends StatefulWidget { @override _LoginScreenState createState()=> _LoginScreenState(); }
class _LoginScreenState extends State<LoginScreen> {
  String email="", pass=""; bool _obscure=true; final _form=GlobalKey<FormState>(); bool loading=false;
  @override Widget build(BuildContext context) {
    return Scaffold(body: Padding(padding: EdgeInsets.all(24), child: Form(key: _form, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.solar_power, size: 60, color: Color(0xFF2E7D32)), Text("SolarConnect", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      SizedBox(height: 20),
      TextFormField(decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), onSaved: (v)=> email=v!),
      SizedBox(height: 12),
      TextFormField(decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), suffixIcon: IconButton(icon: Icon(_obscure? Icons.visibility_off : Icons.visibility), onPressed: ()=> setState(()=> _obscure=!_obscure))), obscureText: _obscure, onSaved: (v)=> pass=v!),
      SizedBox(height: 20),
      loading? CircularProgressIndicator() :
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () async {
        _form.currentState!.save();
        setState(()=> loading=true);
        try{
          var doc = await db.collection('users').doc(email).get();
          if(doc.exists && doc.data()!['pass']==pass){
            currentUser = UserAcc.fromMap(doc.data()!);
            var readSnap = await db.collection('users').doc(email).collection('readings').orderBy('time', descending: true).get();
            currentUser!.readings = readSnap.docs.map((d)=> Reading.fromMap(d.data())).toList();
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> DashboardScreen()));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invalid login or not in Firebase")));
          }
        } catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"))); }
        setState(()=> loading=false);
      }, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF2E7D32)), child: Text("LOGIN", style: TextStyle(color: Colors.white)))),
      TextButton(onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> RegisterScreen())), child: Text("Create Account")),
    ]))));
  }
}
class DashboardScreen extends StatefulWidget { @override _DashboardScreenState createState()=> _DashboardScreenState(); }
class _DashboardScreenState extends State<DashboardScreen> {
  int idx=0;
  final List<Widget> pages = [DashboardTab(), CommunityTab(), AnalyticsTab(), SimulatorTab(), InfoTab()];
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text("SolarConnect"), backgroundColor: Color(0xFF2E7D32), foregroundColor: Colors.white, actions: [IconButton(onPressed: (){ currentUser=null; Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> LoginScreen())); }, icon: Icon(Icons.logout))]),
      body: pages[idx],
      bottomNavigationBar: BottomNavigationBar(currentIndex: idx, selectedItemColor: Color(0xFF2E7D32), type: BottomNavigationBarType.fixed, onTap: (i)=> setState(()=> idx=i), items: [BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"), BottomNavigationBarItem(icon: Icon(Icons.people), label: "Community"), BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Analytics"), BottomNavigationBarItem(icon: Icon(Icons.science), label: "Simulator"), BottomNavigationBarItem(icon: Icon(Icons.info), label: "Info")]),
      floatingActionButton: idx==0? FloatingActionButton.extended(onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> InputScreen(onSaved: ()=> setState((){})))), label: Text("Add Data"), icon: Icon(Icons.add), backgroundColor: Color(0xFF2E7D32)) : null,
    );
  }
}
class DashboardTab extends StatelessWidget {
  @override Widget build(BuildContext context) {
    var user=currentUser!; if(user.readings.isEmpty) return Center(child: Text("No Data - Click Add Data"));
    var latest=user.readings.first; Color c= latest.status=="NORMAL"? Colors.green : latest.status=="WARNING"? Colors.orange : Colors.red;
    return ListView(padding: EdgeInsets.all(16), children: [Card(color: c.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(latest.status, style: TextStyle(color: c, fontWeight: FontWeight.bold)), Text("${latest.perf.toStringAsFixed(1)}%", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)), Text("${latest.actual}/${latest.expected} kW"), Text("V:${latest.voltage} A:${latest.current} T:${latest.temp} Irr:${latest.irradiance}"), Text(latest.message), Text("Causes: ${latest.causes.join(', ')}"), Text(latest.recommendation)])))]);
  }
}
class InputScreen extends StatefulWidget { final VoidCallback onSaved; InputScreen({required this.onSaved}); @override _InputScreenState createState()=> _InputScreenState(); }
class _InputScreenState extends State<InputScreen> {
  double v=225, curr=5.2, temp=44, irr=790, actual=1.4, expected=3.0; bool saving=false;
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text("Add Solar Data")), body: Padding(padding: EdgeInsets.all(16), child: ListView(children: [
      _field("Voltage", v, (x)=> v=x), _field("Current", curr, (x)=> curr=x), _field("Temp", temp, (x)=> temp=x), _field("Irradiance", irr, (x)=> irr=x), _field("Actual kW", actual, (x)=> actual=x), _field("Expected kW", expected, (x)=> expected=x),
      SizedBox(height: 20),
      saving? Center(child: CircularProgressIndicator()) :
      ElevatedButton(onPressed: () async {
        setState(()=> saving=true);
        var res=analyzeAI(actual,expected,temp,irr);
        var r=Reading(voltage: v, current: curr, temp: temp, irradiance: irr, actual: actual, expected: expected, perf: res['perf'], status: res['status'], message: res['msg'], causes: List<String>.from(res['causes']), recommendation: res['rec'], time: DateTime.now());
        await db.collection('users').doc(currentUser!.email).collection('readings').add(r.toMap());
        currentUser!.readings.insert(0, r);
        widget.onSaved();
        setState(()=> saving=false);
        Navigator.pop(context);
      }, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF2E7D32), minimumSize: Size(double.infinity, 50)), child: Text("SUBMIT & SAVE TO FIREBASE", style: TextStyle(color: Colors.white)))
    ])));
  }
  Widget _field(String label, double val, Function(double) onC){ return Padding(padding: EdgeInsets.only(bottom: 10), child: TextFormField(initialValue: val.toString(), decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: TextInputType.number, onChanged: (s){ var d=double.tryParse(s); if(d!=null) onC(d); })); }
}
class CommunityTab extends StatelessWidget {
  @override Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('users').snapshots(),
      builder: (context, snap){
        if(!snap.hasData) return Center(child: CircularProgressIndicator());
        return ListView(padding: EdgeInsets.all(16), children: [
          Text("Community ${snap.data!.docs.length} houses", style: TextStyle(fontWeight: FontWeight.bold)),
         ...snap.data!.docs.map((doc){
            var d=doc.data() as Map<String,dynamic>;
            return Card(child: ListTile(title: Text(d['houseName']?? ''), subtitle: Text("${d['solarType']} | ${d['address']}"), trailing: Text(d['email'])));
          }).toList()
        ]);
      }
    );
  }
}
class AnalyticsTab extends StatefulWidget { @override _AnalyticsTabState createState()=> _AnalyticsTabState(); }
class _AnalyticsTabState extends State<AnalyticsTab> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override void initState(){ super.initState(); _tab=TabController(length: 3, vsync: this); }
  @override Widget build(BuildContext context) {
    var readings=currentUser!.readings; if(readings.isEmpty) return Center(child: Text("No data yet"));
    List<double> daily=[2.2,2.5,2.8,2.4,2.7,1.2,2.6];
    List<double> weekly=[12.5,14.2,11.8,12.7];
    List<double> monthly=[45.0,52.3,48.7,50.1,47.2,49.5];
    List<double> cur = _tab.index==0? daily : _tab.index==1? weekly : monthly;
    double avgPerf = readings.map((e)=> e.perf).reduce((a,b)=> a+b)/readings.length;
    double totalGen = readings.map((e)=> e.actual).reduce((a,b)=> a+b);
    return Column(children: [
      Container(color: Colors.white, child: TabBar(controller: _tab, labelColor: Color(0xFF2E7D32), indicatorColor: Color(0xFF2E7D32), onTap: (_)=> setState((){}), tabs: [Tab(text: "Daily"), Tab(text: "Weekly"), Tab(text: "Monthly")])),
      Expanded(child: ListView(padding: EdgeInsets.all(16), children: [
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Solar Generation", style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          SizedBox(height: 150, child: CustomPaint(painter: _LineChartPainter(cur), size: Size(double.infinity, 150))),
          SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("6AM", style: TextStyle(fontSize: 10)), Text("10AM", style: TextStyle(fontSize: 10)), Text("2PM", style: TextStyle(fontSize: 10)), Text("6PM", style: TextStyle(fontSize: 10))])
        ]))),
        SizedBox(height: 12),
        Row(children: [
          Expanded(child: Card(child: Padding(padding: EdgeInsets.all(12), child: Column(children: [Text("${avgPerf.toStringAsFixed(0)}%", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2E7D32))), Text("Avg Efficiency", style: TextStyle(fontSize: 10))])))),
          Expanded(child: Card(child: Padding(padding: EdgeInsets.all(12), child: Column(children: [Text("${totalGen.toStringAsFixed(1)} kWh", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text("Total Gen", style: TextStyle(fontSize: 10))])))),
          Expanded(child: Card(child: Padding(padding: EdgeInsets.all(12), child: Column(children: [Text("${readings.length}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text("Readings", style: TextStyle(fontSize: 10))])))),
        ]),
        SizedBox(height: 12),
        Text("House Performance", style: TextStyle(fontWeight: FontWeight.bold)),
      ...readings.map((r){ Color c=r.status=="NORMAL"? Colors.green : r.status=="WARNING"? Colors.orange : Colors.red; return Card(child: Padding(padding: EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(currentUser!.houseName, style: TextStyle(fontWeight: FontWeight.bold)), Text("${r.perf.toStringAsFixed(1)}%", style: TextStyle(color: c))]), SizedBox(height: 6), ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: r.perf/100, color: c, minHeight: 8))] ))); }).toList()
      ]))
    ]);
  }
}
class _LineChartPainter extends CustomPainter {
  final List<double> data; _LineChartPainter(this.data);
  @override void paint(Canvas canvas, Size size){
    if(data.isEmpty) return;
    double maxVal=data.reduce((a,b)=> a>b? a:b)*1.2; if(maxVal==0) maxVal=1;
    Paint linePaint=Paint()..color=Color(0xFF2E7D32)..strokeWidth=3..style=PaintingStyle.stroke..strokeCap=StrokeCap.round;
    Paint fillPaint=Paint()..color=Color(0xFF2E7D32).withOpacity(0.15)..style=PaintingStyle.fill;
    Path linePath=Path(); Path fillPath=Path();
    for(int i=0;i<data.length;i++){
      double x=(i/(data.length-1))*size.width; double y=size.height-(data[i]/maxVal)*size.height;
      if(i==0){ linePath.moveTo(x,y); fillPath.moveTo(x,size.height); fillPath.lineTo(x,y); }
      else{ linePath.lineTo(x,y); fillPath.lineTo(x,y); }
      if(i==data.length-1){ fillPath.lineTo(x,size.height); fillPath.close(); }
    }
    canvas.drawPath(fillPath, fillPaint); canvas.drawPath(linePath, linePaint);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}
class SimulatorTab extends StatefulWidget { @override _SimulatorTabState createState()=> _SimulatorTabState(); }
class _SimulatorTabState extends State<SimulatorTab> { double actual=1.4, expected=3.0; String resText=""; @override Widget build(BuildContext context) { return Padding(padding: EdgeInsets.all(20), child: Column(children: [Text("Simulator", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Slider(value: actual, min: 0, max: 5, onChanged: (v)=> setState(()=> actual=v)), Text("Actual $actual kW"), ElevatedButton(onPressed: (){ var r=analyzeAI(actual,expected,44,790); setState(()=> resText="${r['perf'].toStringAsFixed(1)}% - ${r['status']}"); }, child: Text("RUN")), SizedBox(height: 20), Text(resText)])); } }
class InfoTab extends StatelessWidget { @override Widget build(BuildContext context) { return Padding(padding: EdgeInsets.all(16), child: Text("SolarConnect: Clean Energy | Smart Monitoring\n\nTypes: On-Grid, Off-Grid, Hybrid\n\nStatus: NORMAL >=80%, WARNING 50-79%, CRITICAL <50%")); } }