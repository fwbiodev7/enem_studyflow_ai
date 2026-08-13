import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/study_block.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storageService = StorageService();
  final _aiService = AiService();
  final _notificationService = NotificationService();
  
  String? _userName;
  List<StudyBlock> _schedule = [];
  bool _isLoading = false;

  final _subjectsController = TextEditingController();
  final _hoursController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final name = await _storageService.getUserName();
    final schedule = await _storageService.getSchedule();
    setState(() {
      _userName = name;
      if (schedule != null) _schedule = schedule;
    });
  }

  Future<void> _generateSchedule() async {
    final subjects = _subjectsController.text;
    final hours = int.tryParse(_hoursController.text);

    if (subjects.isEmpty || hours == null || hours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha corretamente matérias e horas.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final blocks = await _aiService.generateSchedule(subjects, hours);
      await _storageService.saveSchedule(blocks);
      
      // Agendar notificações locais (15 minutos antes)
      for (var i = 0; i < blocks.length; i++) {
        final block = blocks[i];
        final notificationTime = block.startTime.subtract(const Duration(minutes: 15));
        
        if (notificationTime.isAfter(DateTime.now())) {
          await _notificationService.scheduleNotification(
            id: i,
            title: 'Prepare-se! 🎯',
            body: 'Seu estudo de \${block.subject} começa em 15 minutos.',
            scheduledDate: notificationTime,
          );
        }
      }

      setState(() => _schedule = blocks);
      if (!mounted) return;
      Navigator.pop(context); // Fecha o BottomSheet
      
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [Icon(Icons.error_outline, color: Colors.red), SizedBox(width: 8), Text('Erro')],
        ),
        content: Text(message.replaceAll('Exception: ', '')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _generateSchedule(); // Tentar novamente
            },
            child: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }

  void _showSetupBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24, right: 24, top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Novo Cronograma com IA ✨', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _subjectsController,
              decoration: const InputDecoration(labelText: 'Matérias de dificuldade (ex: Física, Redação)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hoursController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Horas disponíveis hoje', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _generateSchedule,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Gerar Plano de Estudos', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  
  void _updateStatus(int index, String newStatus) async {
    setState(() => _schedule[index].status = newStatus);
    await _storageService.saveSchedule(_schedule);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Olá, \${_userName ?? ''} 📚'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _storageService.saveUserName('');
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: _isLoading 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 24),
                Text('A IA do Gemini está montando\nseu cronograma perfeito...', textAlign: TextAlign.center),
              ],
            ),
          )
        : _schedule.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Nenhum cronograma para hoje.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showSetupBottomSheet,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Gerar com Inteligência Artificial'),
                  )
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _schedule.length,
              itemBuilder: (context, index) {
                final block = _schedule[index];
                final timeFormat = DateFormat('HH:mm');
                
                Color statusColor;
                IconData statusIcon;
                
                switch (block.status) {
                  case 'Concluído':
                    statusColor = Colors.green;
                    statusIcon = Icons.check_circle;
                    break;
                  case 'Em Andamento':
                    statusColor = Colors.blue;
                    statusIcon = Icons.play_circle_fill;
                    break;
                  default:
                    statusColor = Colors.orange;
                    statusIcon = Icons.schedule;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withOpacity(0.15),
                      child: Icon(statusIcon, color: statusColor),
                    ),
                    title: Text(block.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('\${timeFormat.format(block.startTime)} - \${timeFormat.format(block.endTime)}'),
                    trailing: DropdownButton<String>(
                      value: block.status,
                      underline: const SizedBox(),
                      icon: Icon(Icons.arrow_drop_down, color: statusColor),
                      onChanged: (newValue) {
                        if (newValue != null) _updateStatus(index, newValue);
                      },
                      items: ['Pendente', 'Em Andamento', 'Concluído']
                          .map((value) => DropdownMenuItem(value: value, child: Text(value, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))))
                          .toList(),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: _schedule.isNotEmpty && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _showSetupBottomSheet,
              icon: const Icon(Icons.refresh),
              label: const Text('Regerar'),
            )
          : null,
    );
  }
}
