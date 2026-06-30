import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../auth/splash_screen.dart' show GradientButton;

class SosContactsScreen extends StatefulWidget {
  const SosContactsScreen({super.key});

  @override
  State<SosContactsScreen> createState() => _SosContactsScreenState();
}

class _SosContactsScreenState extends State<SosContactsScreen> {
  final _repo = SosRepository();
  late String _uid;
  bool _loading = true;
  String? _error;
  List<SosContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _uid = context.read<AuthProvider>().user?.uid ?? '';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _contacts = await _repo.getSosContacts(_uid);
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(String id) async {
    try {
      await _repo.deleteContact(id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    }
  }

  void _showForm([SosContact? contact]) {
    final nameCtrl   = TextEditingController(text: contact?.name ?? '');
    final emailCtrl  = TextEditingController(text: contact?.email ?? '');
    final phoneCtrl  = TextEditingController(text: contact?.phone ?? '');
    final relCtrl    = TextEditingController(text: contact?.relation ?? '');
    final formKey    = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20,
            20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(contact == null ? 'Agregar contacto SOS' : 'Editar contacto',
                  style: const TextStyle(color: AppColors.textPrimary,
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Correo electrónico'),
                validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Teléfono'),
                validator: (v) => (v == null || v.length < 8) ? 'Teléfono inválido' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: relCtrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Relación (mamá, papá…)'),
              ),
              const SizedBox(height: 20),
              StatefulBuilder(builder: (ctx2, setInner) => GradientButton(
                label: contact == null ? 'Guardar contacto' : 'Actualizar',
                loading: saving,
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  setInner(() => saving = true);
                  final data = {
                    'name': nameCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'relation': relCtrl.text.trim(),
                    'ownerUid': _uid,
                  };
                  try {
                    if (contact == null) {
                      await _repo.addContact(data);
                    } else {
                      await _repo.updateContact(contact.id, data);
                    }
                    if (mounted) { Navigator.pop(ctx); await _load(); }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al guardar: ${e.toString().replaceAll('Exception: ', '')}')),
                      );
                      setInner(() => saving = false);
                    }
                  }
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contactos SOS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () => _showForm(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 56),
              const SizedBox(height: 12),
              Text(
                'Error al cargar contactos',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, color: AppColors.borderColor, size: 56),
            const SizedBox(height: 12),
            const Text('No tenés contactos SOS',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showForm(),
              child: const Text('Agregar contacto'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _contacts.length,
      itemBuilder: (_, i) {
        final c = _contacts[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderColor, width: 0.5),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.catSelectedBg,
              child: Text(
                c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(c.name,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: Text(
              '${c.email}${c.phone.isNotEmpty ? ' · ${c.phone}' : ''}${c.relation.isNotEmpty ? ' · ${c.relation}' : ''}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.textSecondary, size: 18),
                  onPressed: () => _showForm(c),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error, size: 18),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppColors.cardBg,
                        title: const Text('Eliminar contacto',
                            style: TextStyle(color: AppColors.textPrimary)),
                        content: Text('¿Eliminar a ${c.name}?',
                            style: const TextStyle(color: AppColors.textSecondary)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar')),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Eliminar',
                                style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) _delete(c.id);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}