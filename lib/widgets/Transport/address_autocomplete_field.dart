import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui'; // Potrebné pre ImageFilter
import '../../services/transport/transport_service.dart';

class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? apiKey;
  final Function(String)? onAddressSelected;

  const AddressAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.apiKey,
    this.onAddressSelected,
  });

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final TransportService _transportService = TransportService();
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  List<String> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounceTimer;
  bool _isSelecting =
      false; // Flag na indikáciu, že používateľ práve vyberá adresu

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _debounceTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    // Odstránime overlay pri strate fokusu
    if (!_focusNode.hasFocus && !_isSelecting) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _onTextChanged() {
    // Ak práve vyberáme adresu, nechceme znovu načítať návrhy
    if (_isSelecting) {
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (widget.controller.text.length >= 3 && !_isSelecting) {
        _loadSuggestions();
      } else {
        _removeOverlay();
      }
    });
  }

  Future<void> _loadSuggestions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final suggestions = await _transportService.getAddressSuggestions(
        input: widget.controller.text,
        apiKey: widget.apiKey,
      );

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });

        if (_suggestions.isNotEmpty) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _removeOverlay();
      }
    }
  }

  void _showOverlay() {
    _removeOverlay();
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height - 25), // Umiestnenie pod label a field
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: _buildSuggestionList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildSuggestionList() {
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: _suggestions.length,
      separatorBuilder: (context, index) =>
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return ListTile(
          visualDensity: VisualDensity.compact,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Color(0xFF818CF8),
              size: 18,
            ),
          ),
          title: Text(
            suggestion,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          onTap: () {
            // Dočasne odstránime listener, aby sa nespustil pri nastavení textu
            widget.controller.removeListener(_onTextChanged);
            _isSelecting = true;

            // Nastavíme text bez spustenia listenera
            widget.controller.text = suggestion;
            _removeOverlay();
            widget.onAddressSelected?.call(suggestion);

            // Znovu pridáme listener po krátkom čase
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                _isSelecting = false;
                widget.controller.addListener(_onTextChanged);
              }
            });
          },
        );
      },
    );
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
              letterSpacing: 0.5,
            ),
          ),
        ),
        CompositedTransformTarget(
          link: _layerLink,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                prefixIcon: Icon(widget.icon, color: const Color(0xFF818CF8)),
                suffixIcon: _buildSuffixIcon(),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF6366F1),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
              ),
              onTap: () {
                if (_suggestions.isNotEmpty && !_isSelecting) {
                  _showOverlay();
                }
              },
              onChanged: (value) {
                // Resetujeme flag pri zmene textu používateľom (keď používateľ začne písať)
                if (_isSelecting) {
                  _isSelecting = false;
                }
              },
            ),
          ),
        ),
        _buildFooterInfo(),
      ],
    );
  }

  Widget _buildSuffixIcon() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF818CF8),
          ),
        ),
      );
    }
    if (widget.controller.text.isNotEmpty) {
      return IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
        onPressed: () {
          widget.controller.clear();
          _removeOverlay();
        },
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildFooterInfo() {
    if (widget.apiKey != null && widget.apiKey!.isNotEmpty)
      return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            size: 12,
            color: Colors.white.withOpacity(0.4),
          ),
          const SizedBox(width: 6),
          Text(
            'OpenStreetMap engine active',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.4),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
