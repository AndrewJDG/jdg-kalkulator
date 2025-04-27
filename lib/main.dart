// JDG Kalkulator
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(JdgCalculatorApp());
}

class JdgCalculatorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JDG Kalkulator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Color(0xFFF5F5F5),
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController hourlyRateController = TextEditingController();
  final TextEditingController hoursPerWeekController = TextEditingController();
  final TextEditingController weeksController = TextEditingController();

  String selectedTax = 'Podatek liniowy 19%';
  String selectedZus = 'Standardowy ZUS';
  String selectedCurrency = 'PLN';

  double bruto = 0;
  double zus = 0;
  double tax = 0;
  double netto = 0;
  double currencyRate = 4.5; // 1 EUR = 4.5 PLN

  List<Map<String, dynamic>> history = [];

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('history');
    if (data != null) {
      setState(() {
        history = List<Map<String, dynamic>>.from(json.decode(data));
      });
    }
  }

  Future<void> saveHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('history', json.encode(history));
  }

  void calculate() {
    double rate = double.tryParse(hourlyRateController.text) ?? 0;
    double hours = double.tryParse(hoursPerWeekController.text) ?? 0;
    double weeks = double.tryParse(weeksController.text) ?? 0;

    double gross = rate * hours * weeks;
    double zusCost = selectedZus == 'Standardowy ZUS' ? 1600 * (weeks / 4) : 700 * (weeks / 4);
    double taxable = gross - zusCost;
    double taxAmount = selectedTax == 'Podatek liniowy 19%' ? taxable * 0.19 : taxable * 0.12;
    double net = gross - zusCost - taxAmount;

    if (selectedCurrency == 'EUR') {
      gross /= currencyRate;
      zusCost /= currencyRate;
      taxAmount /= currencyRate;
      net /= currencyRate;
    }

    setState(() {
      bruto = gross;
      zus = zusCost;
      tax = taxAmount;
      netto = net;
    });

    history.add({
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'rate': rate,
      'hours': hours,
      'weeks': weeks,
      'bruto': bruto,
      'zus': zus,
      'tax': tax,
      'netto': netto,
      'currency': selectedCurrency,
      'taxForm': selectedTax,
      'zusForm': selectedZus,
    });

    saveHistory();
  }

  Future<void> generatePDF() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Kalkulacja JDG', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text('Data: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}'),
            pw.Text('Waluta: $selectedCurrency'),
            pw.Text('Forma opodatkowania: $selectedTax'),
            pw.Text('Typ ZUS: $selectedZus'),
            pw.SizedBox(height: 10),
            pw.Text('Brutto: ${bruto.toStringAsFixed(2)} $selectedCurrency'),
            pw.Text('ZUS: ${zus.toStringAsFixed(2)} $selectedCurrency'),
            pw.Text('Podatek: ${tax.toStringAsFixed(2)} $selectedCurrency'),
            pw.Text('Netto: ${netto.toStringAsFixed(2)} $selectedCurrency'),
          ],
        ),
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/Kalkulacja_JDG_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareFiles([file.path], text: 'Moja kalkulacja JDG');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('JDG Kalkulator'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => HistoryPage(history: history)));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextField(
            controller: hourlyRateController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Stawka (€/zł za godzinę)', border: OutlineInputBorder()),
          ),
          SizedBox(height: 10),
          TextField(
            controller: hoursPerWeekController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Godzin tygodniowo', border: OutlineInputBorder()),
          ),
          SizedBox(height: 10),
          TextField(
            controller: weeksController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Liczba tygodni', border: OutlineInputBorder()),
          ),
          SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedTax,
            items: ['Podatek liniowy 19%', 'Zasady ogólne 12%']
                .map((label) => DropdownMenuItem(child: Text(label), value: label))
                .toList(),
            onChanged: (value) => setState(() => selectedTax = value!),
            decoration: InputDecoration(labelText: 'Forma opodatkowania', border: OutlineInputBorder()),
          ),
          SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedZus,
            items: ['Standardowy ZUS', 'Preferencyjny ZUS']
                .map((label) => DropdownMenuItem(child: Text(label), value: label))
                .toList(),
            onChanged: (value) => setState(() => selectedZus = value!),
            decoration: InputDecoration(labelText: 'Typ ZUS', border: OutlineInputBorder()),
          ),
          SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedCurrency,
            items: ['PLN', 'EUR']
                .map((label) => DropdownMenuItem(child: Text(label), value: label))
                .toList(),
            onChanged: (value) => setState(() => selectedCurrency = value!),
            decoration: InputDecoration(labelText: 'Waluta', border: OutlineInputBorder()),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: calculate,
            child: Text('Oblicz'),
            style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16.0)),
          ),
          SizedBox(height: 20),
          Card(
            elevation: 3,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Brutto: ${bruto.toStringAsFixed(2)} $selectedCurrency'),
                  Text('ZUS: ${zus.toStringAsFixed(2)} $selectedCurrency'),
                  Text('Podatek: ${tax.toStringAsFixed(2)} $selectedCurrency'),
                  Text('Netto: ${netto.toStringAsFixed(2)} $selectedCurrency'),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: generatePDF,
            child: Text('Eksportuj do PDF'),
            style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16.0)),
          ),
        ],
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const HistoryPage({required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Historia kalkulacji')),
      body: ListView.builder(
        itemCount: history.length,
        itemBuilder: (context, index) {
          var item = history[index];
          return ListTile(
            title: Text('Data: ${item['date']} - Netto: ${item['netto'].toStringAsFixed(2)} ${item['currency']}'),
            subtitle: Text('Stawka: ${item['rate']} zł | ${item['hours']}h/tydz. | ${item['weeks']} tyg.'),
          );
        },
      ),
    );
  }
}
