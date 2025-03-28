import 'package:meta/meta.dart';
import 'package:replicate/src/instance/predictions/stream/predictions.dart';
import 'package:replicate/src/models/predictions/prediction.dart';
import 'package:replicate/src/network/builder/endpoint_url.dart';
import 'package:replicate/src/network/http_client.dart';

import '../../base/predictions_base.dart';
import '../../models/predictions_pagination/predictions_pagination.dart';

class ReplicatePrediction implements ReplicatePredictionBase {
  final Map<String, PredictionStream> _predictionsStreamRegistry = {};

  @override
  Future cancel({
    required String id,
  }) {
    return ReplicateHttpClient.post(
      to: EndpointUrlBuilder.build(['predictions', id, 'cancel']),
      onSuccess: (Map<String, dynamic> response) {
        return response;
      },
    );
  }

  @override
  Future<Prediction> create({
    required String version,
    required Map<String, dynamic> input,
    String? webhookCompleted,
  }) {
    return ReplicateHttpClient.post(
      to: EndpointUrlBuilder.build(['predictions']),
      body: {
        'version': version,
        'input': input,
        if (webhookCompleted != null) "webhook_completed": webhookCompleted,
      },
      onSuccess: (Map<String, dynamic> response) {
        return Prediction.fromJson(response);
      },
    );
  }

  @override
  Future<Prediction> get({required String id}) async {
    return await ReplicateHttpClient.get(
      from: EndpointUrlBuilder.build(['predictions', id]),
      onSuccess: (Map<String, dynamic> response) {
        return Prediction.fromJson(response);
      },
    );
  }

  @internal
  Future<PredictionsPagination> listPredictionsFromApiLink({
    required String url,
  }) async {
    return await ReplicateHttpClient.get(
      from: url,
      onSuccess: (Map<String, dynamic> response) {
        return PredictionsPagination.fromJson(response);
      },
    );
  }

  @override
  Future<PredictionsPagination> list() async {
    return await listPredictionsFromApiLink(
      url: EndpointUrlBuilder.build(['predictions']),
    );
  }

  @override
  Stream<Prediction> snapshots({
    required String id,
    Duration pollingInterval = const Duration(seconds: 3),
    bool shouldTriggerOnlyStatusChanges = true,
    bool stopPollingRequestsOnPredictionTermination = true,
  }) {
    if (_predictionsStreamRegistry.containsKey(id)) {
      return _predictionsStreamRegistry[id]!.stream;
    } else {
      final predictionStream = PredictionStream(
        pollingCallback: () async {
          return await get(id: id);
        },
        pollingInterval: pollingInterval,
        shouldTriggerOnlyStatusChanges: shouldTriggerOnlyStatusChanges,
        stopPollingRequestsOnPredictionTermination:
            stopPollingRequestsOnPredictionTermination,
      );

      _predictionsStreamRegistry[id] = predictionStream;
      return predictionStream.stream;
    }
  }

  Stream<PredictionStatus> statusSnapshots({
    required String id,
    Duration pollingInterval = const Duration(seconds: 3),
  }) {
    return snapshots(
      id: id,
      pollingInterval: pollingInterval,
      shouldTriggerOnlyStatusChanges: true,
    ).asyncMap<PredictionStatus>((prediction) {
      return prediction.status;
    });
  }

  Stream<String> logsSnapshots({
    required String id,
    Duration pollingInterval = const Duration(seconds: 3),
    bool shouldTriggerOnlyStatusChanges = true,
  }) {
    return snapshots(
      id: id,
      pollingInterval: pollingInterval,
      shouldTriggerOnlyStatusChanges: shouldTriggerOnlyStatusChanges,
    ).asyncMap<String>((prediction) {
      return prediction.logs;
    });
  }
}
