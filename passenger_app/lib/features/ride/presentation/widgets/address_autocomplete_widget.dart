import 'dart:async';
import 'package:flutter/material.dart';
import '../services/geocoding_service.dart';

class AddressAutocompleteWidget extends StatefulWidget {
  final String hintText;
  final Function(String) onAddressSelected;
  final String initialValue;

  const AddressAutocompleteWidget({
    super.key,
    required this.hintText,
    required this.onAddressSelected,
    this.initialValue = '',
  });

  @override
  State<AddressAutocompleteWidget> createState() =>
      _AddressAutocompleteWidgetState();
}

class _AddressAutocompleteWidgetState extends State<AddressAutocompleteWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<PlaceSuggestion> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialValue;
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      setState(() {
        _suggestions = [];
      });
    }
  }

  void _onTextChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(text);
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (query.length < 3) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final suggestions = await GeocodingService.searchPlaces(query);
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
      }
    }
  }

  void _selectSuggestion(PlaceSuggestion suggestion) {
    _controller.text = suggestion.displayName;
    widget.onAddressSelected(suggestion.displayName);
    setState(() {
      _suggestions = [];
    });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: widget.hintText,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 16,
            ),
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          onChanged: _onTextChanged,
        ),

        // Suggestions list
        if (_suggestions.isNotEmpty || _isLoading)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  ..._suggestions
                      .map((suggestion) => _buildSuggestionItem(suggestion)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSuggestionItem(PlaceSuggestion suggestion) {
    return InkWell(
      onTap: () => _selectSuggestion(suggestion),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.location_on,
              color: Colors.grey.shade400,
              size: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (suggestion.city != null)
                    Text(
                      suggestion.city!,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
