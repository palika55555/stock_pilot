import 'package:flutter/material.dart';
import '../../services/Database/database_service.dart';
import '../../models/user.dart';
import '../../widgets/common/standard_text_field.dart';

class ProfilePage extends StatefulWidget {
  final int? userId;
  final String userName;
  final String userRole;
  final String? avatarUrl;
  final String email;
  final String phone;
  final String department;
  final DateTime joinDate;

  const ProfilePage({
    super.key,
    this.userId,
    required this.userName,
    required this.userRole,
    this.avatarUrl,
    required this.email,
    required this.phone,
    required this.department,
    required this.joinDate,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditing = false;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _departmentController;
  late TextEditingController _nameController;
  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email);
    _phoneController = TextEditingController(text: widget.phone);
    _departmentController = TextEditingController(text: widget.department);
    _nameController = TextEditingController(text: widget.userName);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  Future<void> _saveChanges() async {
    if (widget.userId == null) return;

    // Fetch the username first since we don't have it in the controller
    // but we need it for the DB object. In a real app, you'd store it in state.
    // For now, let's assume we can update just the other fields if we had a better SQL query,
    // but here we'll just update everything.
    
    // Simplification: We'll need the original user to keep the username
    final originalUser = await _dbService.getUserByUsername(widget.userName == 'Pavol Administrátor' ? 'admin' : 'skladnik');
    
    if (originalUser != null) {
      final userToSave = User(
        id: widget.userId,
        username: originalUser.username,
        password: originalUser.password,
        fullName: _nameController.text,
        role: widget.userRole,
        email: _emailController.text,
        phone: _phoneController.text,
        department: _departmentController.text,
        avatarUrl: widget.avatarUrl ?? '',
        joinDate: widget.joinDate,
      );

      await _dbService.updateUser(userToSave);

      if (mounted) {
        setState(() {
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zmeny boli uložené do databázy!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_isEditing ? 'Upraviť profil' : 'Profil'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isEditing) {
              setState(() {
                _isEditing = false;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
            ),
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _emailController.text = widget.email;
                  _phoneController.text = widget.phone;
                  _departmentController.text = widget.department;
                  _nameController.text = widget.userName;
                });
              },
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _toggleEdit,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header s avatarom a základnými info
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blue[800],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Avatar
                  Hero(
                    tag: 'profile-avatar',
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      backgroundImage: widget.avatarUrl != null ? NetworkImage(widget.avatarUrl!) : null,
                      child: widget.avatarUrl == null
                          ? const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 60,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Meno a rola
                  if (_isEditing)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: TextField(
                        controller: _nameController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                        ),
                      ),
                    )
                  else
                    Text(
                      widget.userName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.userRole == 'admin' ? Colors.red : Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.userRole.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Detailné informácie
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Kontaktné informácie
                  _buildSection(
                    title: 'Kontaktné informácie',
                    children: [
                      _buildInfoTile(
                        icon: Icons.email_outlined,
                        title: 'Email',
                        value: _isEditing ? _emailController : widget.email,
                        onTap: _isEditing ? () {} : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Email: ${widget.email}')),
                          );
                        },
                        edit: _isEditing,
                        controller: _emailController,
                      ),
                      _buildInfoTile(
                        icon: Icons.phone_outlined,
                        title: 'Telefón',
                        value: _isEditing ? _phoneController : widget.phone,
                        onTap: _isEditing ? () {} : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Telefón: ${widget.phone}')),
                          );
                        },
                        edit: _isEditing,
                        controller: _phoneController,
                      ),
                      _buildInfoTile(
                        icon: Icons.business_outlined,
                        title: 'Oddelenie',
                        value: _isEditing ? _departmentController : widget.department,
                        onTap: _isEditing ? () {} : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Oddelenie: ${widget.department}')),
                          );
                        },
                        edit: _isEditing,
                        controller: _departmentController,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Pracovné informácie
                  _buildSection(
                    title: 'Pracovné informácie',
                    children: [
                      _buildInfoTile(
                        icon: Icons.calendar_today_outlined,
                        title: 'Dátum nástupu',
                        value: '${widget.joinDate.day}. ${_getMonthName(widget.joinDate.month)} ${widget.joinDate.year}',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Dátum nástupu: ${widget.joinDate.day}.${widget.joinDate.month}.${widget.joinDate.year}')),
                          );
                        },
                      ),
                      _buildInfoTile(
                        icon: Icons.work_outline,
                        title: 'Pozícia',
                        value: widget.userRole == 'admin' ? 'Skladový administrátor' : 'Skladník',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Pozícia: ${widget.userRole == 'admin' ? 'Skladový administrátor' : 'Skladník'}')),
                          );
                        },
                      ),
                      _buildInfoTile(
                        icon: Icons.schedule_outlined,
                        title: 'Pracovný čas',
                        value: 'Po-Pia: 7:00 - 15:30',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pracovný čas: Po-Pia: 7:00 - 15:30')),
                          );
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Štatistiky
                  _buildSection(
                    title: 'Štatistiky',
                    children: [
                      _buildStatsTile(
                        icon: Icons.inventory_2_outlined,
                        title: 'Spracované objednávky',
                        value: '1,247',
                        color: Colors.blue,
                      ),
                      _buildStatsTile(
                        icon: Icons.local_shipping_outlined,
                        title: 'Vydania tovaru',
                        value: '892',
                        color: Colors.green,
                      ),
                      _buildStatsTile(
                        icon: Icons.access_time_outlined,
                        title: 'Pracovné hodiny',
                        value: '1,456',
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Nastavenia
                  _buildSection(
                    title: 'Nastavenia',
                    children: [
                      ListTile(
                        leading: const Icon(Icons.notifications_outlined, color: Colors.blue),
                        title: const Text('Notifikácie'),
                        trailing: Switch(
                          value: true,
                          onChanged: (value) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Notifikácie ${value ? 'zapnuté' : 'vypnuté'}')),
                            );
                          },
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.dark_mode_outlined, color: Colors.grey),
                        title: const Text('Tmavý režim'),
                        trailing: Switch(
                          value: false,
                          onChanged: (value) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Tmavý režim ${value ? 'zapnutý' : 'vypnutý'}')),
                            );
                          },
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.language_outlined, color: Colors.purple),
                        title: const Text('Jazyk'),
                        trailing: const Text('Slovenčina'),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Zmena jazyka - v príprave')),
                          );
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5, bottom: 10),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required dynamic value,
    required VoidCallback onTap,
    bool edit = false,
    TextEditingController? controller,
  }) {
    if (edit && controller != null) {
      return ListTile(
        leading: Icon(icon, color: Colors.blue[600]),
        title: Text(title),
        subtitle: StandardTextField(
          controller: controller,
          labelText: '',
          icon: null,
        ),
        trailing: const Icon(Icons.edit, color: Colors.blue),
        onTap: () {},
      );
    }
    
    return ListTile(
      leading: Icon(icon, color: Colors.blue[600]),
      title: Text(title),
      subtitle: Text(value.toString()),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildStatsTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'január', 'február', 'marec', 'apríl', 'máj', 'jún',
      'júl', 'august', 'september', 'október', 'november', 'december'
    ];
    return months[month - 1];
  }
}