import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '/models/medic.dart';
import '/db/dbhelper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  final String timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName));




  await NotificationService().init();

  runApp(const MedApp());
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();


  Future<void> checkPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final bool? granted = await androidPlugin.requestNotificationsPermission ();
      if (granted != null && granted) {
        print("Permissão concedida!");
      } else {
        print("Permissão negada!");
      }
    } else {
      print("Não é Android ou plugin não disponível");
    }
  }

  Future<void> init() async {
    // Inicializa TimeZone
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    print("Fuso horário detectado: $timeZoneName");
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    // Configura Android
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
    InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);

    // Cria canal Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'med_channel', // id
      'Medicamentos', // nome
      description: 'Canal para notificações de medicamentos',
      importance: Importance.max,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Agenda uma notificação para o horário do medicamento
  Future<void> scheduleNotification(
      int medId, String title, String body, TimeOfDay time) async {
    final location = tz.local;
    final now = tz.TZDateTime.now(location);
    print("Agora no TZDateTime: $now");


    // Cria o horário do medicamento
    tz.TZDateTime scheduleTZ = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // Se horário já passou hoje, agenda para amanhã
    if (scheduleTZ.isBefore(now)) {
      scheduleTZ = scheduleTZ.add(const Duration(days: 1));
    }

    // Gera ID único por medicamento e horário
    final int notificationId = medId.hashCode + time.hour * 100 + time.minute;

    print("Agendando notificação para: $scheduleTZ (ID $notificationId)");

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      scheduleTZ,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'med_channel',
          'Medicamentos',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repete diariamente
    );
  }

  /// Cancela todas notificações (opcional)
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

class MedApp extends StatelessWidget {
  const MedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gerenciador de Medicamentos',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const WelcomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade100,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Image(image: AssetImage('assets/images/logosemitrans.png')),
              const SizedBox(height: 20),
              const Text(
                "Bem-vindo ao gerenciador de medicamentos Cuida+",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Aqui você pode cadastrar seus remédios e organizar sua rotina de forma prática.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: Colors.teal,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                },
                child: const Text(
                  "Entrar",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  final NotificationService _notificationService = NotificationService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Medicine> _medicine = [];

  @override
  void initState() {
    super.initState();
    _loadMed();
  }

  Future<void> _loadMed() async {
    final meds = await _dbHelper.getMed();
    setState(() {
      _medicine = meds;
    });
  }

  List<DateTime> _getCurrentWeek() {
    DateTime today = DateTime.now();
    int weekday = today.weekday;
    DateTime monday = today.subtract(Duration(days: weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  Future<String?> _pickImage() async {
    final XFile? pickedFile =
    await _picker.pickImage(source: ImageSource.gallery);
    return pickedFile?.path;
  }

  void _openForm({Medicine? med}) {
    String medName = med?.medName ?? "";
    String medDose = med?.medDose ?? "";
    List<TimeOfDay> medTimes = List.from(med?.medTimes ?? []);
    String? selectedImagePath = med?.imagePath;
    String? observations = med?.observations ?? "";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateSB) {
          return AlertDialog(
            title: Text(med == null ? "Adicionar Medicamento" : "Editar Medicamento"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: "Nome"),
                    controller: TextEditingController(text: medName),
                    onChanged: (v) => medName = v,
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: "Dosagem"),
                    controller: TextEditingController(text: medDose),
                    onChanged: (v) => medDose = v,
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: [
                      ...medTimes.asMap().entries.map((entry) {
                        int i = entry.key;
                        TimeOfDay time = entry.value;
                        return ListTile(
                          title: Text("Horário ${i + 1}: ${time.format(context)}"),
                          trailing: IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: () async {
                              TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: time,
                              );
                              if (picked != null) {
                                setStateSB(() => medTimes[i] = picked);
                              }
                            },
                          ),
                        );
                      }),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Adicionar horário"),
                        onPressed: () async {
                          TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: const TimeOfDay(hour: 8, minute: 0),
                          );
                          if (picked != null) {
                            setStateSB(() => medTimes.add(picked));
                          }
                        },
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      String? path = await _pickImage();
                      if (path != null) {
                        setStateSB(() => selectedImagePath = path);
                      }
                    },
                    icon: const Icon(Icons.image),
                    label: Text(selectedImagePath != null
                        ? "Trocar Imagem"
                        : "Adicionar Imagem"),
                  ),
                  if (selectedImagePath != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Image.file(
                        File(selectedImagePath!),
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(labelText: "Observações"),
                    controller: TextEditingController(text: observations),
                    maxLines: 3,
                    onChanged: (v) => observations = v,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar")),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  if (medName.isNotEmpty &&
                      medDose.isNotEmpty &&
                      medTimes.isNotEmpty) {
                    if (med == null) {
                      // inserir novo
                      final novoMed = Medicine(
                        medName: medName,
                        medDose: medDose,
                        medTimes: medTimes,
                        imagePath: selectedImagePath,
                        observations: observations,
                      );
                      await _dbHelper.insertMed(novoMed);
                    } else {
                      // atualizar existente
                      med.medName = medName;
                      med.medDose = medDose;
                      med.medTimes = medTimes;
                      med.imagePath = selectedImagePath;
                      med.observations = observations;
                      await _dbHelper.updateMed(med);
                    }

                    await _loadMed();

                    for (var t in medTimes) {
                      await NotificationService().scheduleNotification(
                        med?.id ?? DateTime.now().millisecondsSinceEpoch, // ID único
                        "Hora do Remédio",
                        "$med.medName - $med.medDose",
                        t,
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Preencha todos os campos obrigatórios.")),
                    );
                  }
                },
                child: const Text("Salvar"),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _removeMed(Medicine med) async {
    if (med.id != null) {
      await _dbHelper.deleteMed(med.id!);
      await _loadMed();
    }
  }

  @override
  Widget build(BuildContext context) {
    List<DateTime> weekDays = _getCurrentWeek();
    DateTime today = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Meus Medicamentos"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ---- calendário semanal ----
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: weekDays.length,
              itemBuilder: (context, i) {
                bool isToday = weekDays[i].day == today.day &&
                    weekDays[i].month == today.month &&
                    weekDays[i].year == today.year;
                return Container(
                  width: 60,
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isToday ? Colors.teal : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"][i],
                            style: TextStyle(
                              color: isToday ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            )),
                        Text("${weekDays[i].day}",
                            style: TextStyle(
                              color: isToday ? Colors.white : Colors.black,
                            )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 28, color: Colors.white),
                label: const Text("Adicionar Medicamento",
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _openForm(),
              ),
            ),
          ),
          Expanded(
            child: _medicine.isEmpty
                ? const Center(
              child: Text("Nenhum medicamento cadastrado."),
            )
                : ListView.builder(
              itemCount: _medicine.length,
              itemBuilder: (context, index) {
                final med = _medicine[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: ExpansionTile(
                    title: Text("${med.medName} - ${med.medDose}"),
                    subtitle: Text("Horários: " +
                        med.medTimes.map((t) => t.format(context)).join(', ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _openForm(med: med),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeMed(med),
                        ),
                      ],
                    ),
                    children: [
                      if (med.imagePath != null)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Image.file(
                            File(med.imagePath!),
                            height: 150,
                            width: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                      if (med.observations != null &&
                          med.observations!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text("Observações: ${med.observations}"),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}