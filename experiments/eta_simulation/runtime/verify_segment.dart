import 'dart:convert';
import 'dart:io';
import '../../../packages/giaohang_mobile/lib/core/ml/eta_simulation/model.dart';
import '../../../packages/giaohang_mobile/lib/core/ml/eta_simulation/profile.dart';

dynamic read(String name) => jsonDecode(File('output/eta_simulation/segment_ai/$name.json').readAsStringSync());
void main() {
  final model = EtaCorrectionModel(Map<String,dynamic>.from(read('model')));
  final context = Map<String,dynamic>.from(read('context'));
  var modelError=0.0, durationError=0.0, sectionError=0.0;
  for(final f in read('parity_vectors') as List) {
    final vector=(f['features'] as List).map((v)=>(v as num).toDouble()).toList();
    final e=(model.predict(vector)-(f['expected_speed_kmh'] as num)).abs();
    if(e>modelError) modelError=e;
  }
  final cases=read('parity_profiles') as List,timings=<double>[];
  for(final f in cases) {
    final tick=Stopwatch()..start();
    final p=buildEtaProfile(Map<String,dynamic>.from(f['route']),f['at'],model,context);
    timings.add(tick.elapsedMicroseconds/1000);
    final expected=f['expected_profile'];
    if(p['used_ai']!=true||p['profile_version']!=6) throw StateError('AI_NOT_PRIMARY');
    final e=((p['travel_minutes'] as num)-(expected['travel_minutes'] as num)).abs()*60;
    if(e>durationError) durationError=e.toDouble();
    final sections=p['speed_profile'] as List,other=expected['speed_profile'] as List;
    if(sections.length!=other.length) throw StateError('SECTION_MISMATCH');
    for(var i=0;i<sections.length;i++) {
      for(final key in ['start_meters','end_meters','speed_kmh','reference_speed_kmh','travel_minutes']) {
        final error=((sections[i][key] as num)-(other[i][key] as num)).abs();
        if(error>sectionError) sectionError=error.toDouble();
      }
      if(sections[i]['segment_id']!=other[i]['segment_id']) throw StateError('FEATURE_MISMATCH');
    }
  }
  if(modelError>1e-8||durationError>1e-6||sectionError>1e-6) throw StateError('SEGMENT_MODEL_PARITY_FAILED');
  timings.sort();
  final report={'model_cases':1000,'route_cases':cases.length,'maximum_model_error':modelError,
    'maximum_duration_error_seconds':durationError,'maximum_section_error':sectionError,
    'warm_p50_ms':timings[(timings.length*.5).floor()],'warm_p90_ms':timings[(timings.length*.9).floor()]};
  File('output/eta_simulation/segment_ai/dart_verification.json').writeAsStringSync(jsonEncode(report));
  print(jsonEncode(report));
}
