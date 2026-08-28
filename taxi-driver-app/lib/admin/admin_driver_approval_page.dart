import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taxiapp/api/admin_api.dart';
import 'package:taxiapp/core/app_colors.dart';

class AdminDriverApprovalPage extends StatefulWidget {
  const AdminDriverApprovalPage({super.key});

  @override
  State<AdminDriverApprovalPage> createState() => _AdminDriverApprovalPageState();
}

class _AdminDriverApprovalPageState extends State<AdminDriverApprovalPage> {
  final _keyCtrl = TextEditingController(text: 'dev-admin-key');
  final _searchCtrl = TextEditingController();
  final _quickApproveCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _approved = [];

  @override
  void dispose() {
    _keyCtrl.dispose();
    _searchCtrl.dispose();
    _quickApproveCtrl.dispose();
    super.dispose();
  }

  Future<void> _quickApproveLogin() async {
    final login = _quickApproveCtrl.text.trim();
    if (login.isEmpty) return;
    final api = AdminApi(adminKey: _keyCtrl.text.trim());
    final result = await api.approveByLogin(login);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? (result.success ? 'Approved' : 'Failed')),
        backgroundColor: result.success ? AppColors.green : AppColors.danger,
      ),
    );
    if (result.success) await _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = AdminApi(adminKey: _keyCtrl.text.trim());
    final q = _searchCtrl.text.trim();
    final pending = await api.fetchPending(q: q.isEmpty ? null : q);
    final approved = await api.fetchApproved(q: q.isEmpty ? null : q);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _pending = pending.drivers;
      _approved = approved.drivers;
      _error = pending.error ?? approved.error;
    });
  }

  Future<void> _approve(String driverId, String label) async {
    final api = AdminApi(adminKey: _keyCtrl.text.trim());
    final result = await api.approve(driverId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? (result.success ? 'Approved $label' : 'Failed')),
        backgroundColor: result.success ? AppColors.green : AppColors.danger,
      ),
    );
    if (result.success) await _refresh();
  }

  void _copyId(String id) {
    Clipboard.setData(ClipboardData(text: id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied driver ID: $id')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldDark,
      appBar: AppBar(
        backgroundColor: AppColors.cardDark,
        title: const Text('Admin — driver approval'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Approve new drivers (email + password). After approve they can go online and accept bookings. Documents are optional.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _keyCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Admin API key',
                hintText: 'dev-admin-key',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: 'Search (name / email / phone)',
                hintText: 'kiruba12',
              ),
              onSubmitted: (_) => _refresh(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _refresh,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('Refresh lists'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quickApproveCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Quick approve login id',
                      hintText: 'kiruba12',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _quickApproveLogin,
                  child: const Text('Approve'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 24),
            Text('Pending (${_pending.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (_pending.isEmpty && !_loading)
              const Text('No drivers waiting for approval'),
            ..._pending.map(_pendingCard),
            const SizedBox(height: 24),
            Text('Approved (${_approved.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ..._approved.map(_approvedTile),
          ],
        ),
      ),
    );
  }

  Widget _pendingCard(Map<String, dynamic> d) {
    final id = (d['driver_id'] ?? d['id'] ?? '').toString();
    final name = d['name']?.toString() ?? 'Driver';
    final email = d['email']?.toString() ?? '';
    return Card(
      color: AppColors.cardDark,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text(email, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            SelectableText('Driver ID: $id', style: const TextStyle(fontSize: 12)),
            Row(
              children: [
                TextButton(onPressed: () => _copyId(id), child: const Text('Copy ID')),
                const Spacer(),
                FilledButton(
                  onPressed: id.isEmpty ? null : () => _approve(id, name),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _approvedTile(Map<String, dynamic> d) {
    final id = (d['driver_id'] ?? d['id'] ?? '').toString();
    return ListTile(
      tileColor: AppColors.cardDark,
      title: Text(d['name']?.toString() ?? 'Driver'),
      subtitle: Text('${d['email'] ?? ''}\nID: $id'),
      isThreeLine: true,
      trailing: const Icon(Icons.check_circle, color: AppColors.green),
      onTap: () => _copyId(id),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }
}
