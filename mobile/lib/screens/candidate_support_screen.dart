import 'package:flutter/material.dart';

import '../widgets/workspace_widgets.dart';

/// API boundary for application support. Employers never access this data.
abstract interface class CandidateSupportRepository {
  Future<List<CandidateMessage>> messages(String applicationId);
  Future<List<InterviewAppointment>> interviews(String applicationId);
  Future<List<AccommodationRequest>> requests(String applicationId);
  Future<void> sendMessage(String applicationId, String message);
  Future<void> requestAccommodation(
    String applicationId,
    String type,
    String details,
  );
}

class CandidateMessage {
  const CandidateMessage(
    this.body,
    this.sentAt, {
    required this.fromAdministrator,
  });
  final String body;
  final DateTime sentAt;
  final bool fromAdministrator;
}

class InterviewAppointment {
  const InterviewAppointment(
    this.when,
    this.location,
    this.status, {
    this.accessibilityNotes,
  });
  final DateTime when;
  final String location, status;
  final String? accessibilityNotes;
}

class AccommodationRequest {
  const AccommodationRequest(
    this.type,
    this.details,
    this.status, {
    this.adminNote,
  });
  final String type, details, status;
  final String? adminNote;
}

class CandidateSupportScreen extends StatefulWidget {
  const CandidateSupportScreen({
    required this.applicationId,
    required this.repository,
    super.key,
  });
  final String applicationId;
  final CandidateSupportRepository repository;
  @override
  State<CandidateSupportScreen> createState() => _CandidateSupportScreenState();
}

class _CandidateSupportScreenState extends State<CandidateSupportScreen> {
  final _message = TextEditingController();
  final _request = TextEditingController();
  String _type = 'interview_access';
  bool _busy = false;
  String? _notice;
  late Future<
    ({
      List<CandidateMessage> messages,
      List<InterviewAppointment> interviews,
      List<AccommodationRequest> requests,
    })
  >
  _data = _load();

  Future<
    ({
      List<CandidateMessage> messages,
      List<InterviewAppointment> interviews,
      List<AccommodationRequest> requests,
    })
  >
  _load() async {
    final values = await Future.wait([
      widget.repository.messages(widget.applicationId),
      widget.repository.interviews(widget.applicationId),
      widget.repository.requests(widget.applicationId),
    ]);
    return (
      messages: values[0] as List<CandidateMessage>,
      interviews: values[1] as List<InterviewAppointment>,
      requests: values[2] as List<AccommodationRequest>,
    );
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.sendMessage(
        widget.applicationId,
        _message.text.trim(),
      );
      _message.clear();
      if (mounted) {
        setState(() {
          _notice = 'Message sent.';
          _data = _load();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice = 'Your message could not be sent. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitRequest() async {
    if (_request.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.requestAccommodation(
        widget.applicationId,
        _type,
        _request.text.trim(),
      );
      _request.clear();
      if (mounted) {
        setState(() {
          _notice = 'Accommodation request sent.';
          _data = _load();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice = 'Your request could not be sent. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _message.dispose();
    _request.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const CareerHeading('Application support'),
      const Text(
        'Messages are handled by the System Administrator and relayed to the company when appropriate.',
      ),
      if (_notice != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(liveRegion: true, child: Text(_notice!)),
        ),
      FutureBuilder(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const BusyIndicator(label: 'Loading application support');
          }
          if (snapshot.hasError) {
            return SectionCard(
              title: 'Support information unavailable',
              children: [
                TextButton(
                  onPressed: () => setState(() => _data = _load()),
                  child: const Text('Try again'),
                ),
              ],
            );
          }
          final data = snapshot.requireData;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                title: 'Interview schedule',
                children: data.interviews.isEmpty
                    ? [const Text('No interview has been scheduled.')]
                    : [
                        for (final i in data.interviews)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              MaterialLocalizations.of(context)
                                  .formatFullDate(i.when),
                            ),
                            subtitle: Text(
                              '${i.location}\n${i.accessibilityNotes ?? ''}',
                            ),
                            trailing: Text(i.status),
                          ),
                      ],
              ),
              SectionCard(
                title: 'Accommodation request',
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    items: const [
                      DropdownMenuItem(
                        value: 'interview_access',
                        child: Text('Interview access'),
                      ),
                      DropdownMenuItem(
                        value: 'workplace_access',
                        child: Text('Workplace access'),
                      ),
                      DropdownMenuItem(
                        value: 'communication',
                        child: Text('Communication'),
                      ),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _type = value ?? _type),
                  ),
                  TextField(
                    controller: _request,
                    maxLength: 4000,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Describe the accommodation you need',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _busy ? null : _submitRequest,
                    child: const Text('Send accommodation request'),
                  ),
                  for (final r in data.requests)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.type),
                      subtitle: Text(
                        r.details +
                            (r.adminNote == null ? '' : '\n${r.adminNote}'),
                      ),
                      trailing: Text(r.status),
                    ),
                ],
              ),
              SectionCard(
                title: 'Messages',
                children: [
                  for (final m in data.messages)
                    Align(
                      alignment: m.fromAdministrator
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(m.body),
                      ),
                    ),
                  TextField(
                    controller: _message,
                    maxLength: 4000,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Write a message to the administrator',
                    ),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : _send,
                    child: const Text('Send message'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ],
  );
}
