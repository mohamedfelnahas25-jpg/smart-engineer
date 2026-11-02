
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const SmartEngineerApp());

const navy = Color(0xFF10243A);
const gold = Color(0xFFE0AD45);
const bg = Color(0xFFF4F6F8);

class SmartEngineerApp extends StatelessWidget {
  const SmartEngineerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'المهندس الذكي',
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: navy),
      appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white)),
    home: const HomePage(),
  );
}

class CalcField {
  final String keyName, label, unit;
  final double initial;
  const CalcField(this.keyName, this.label, this.unit, [this.initial = 0]);
}
class CalcDef {
  final String id, title, category, formula, note, resultUnit;
  final List<CalcField> fields;
  final double Function(Map<String,double>) calculate;
  const CalcDef({required this.id, required this.title, required this.category,
    required this.formula, required this.note, required this.resultUnit,
    required this.fields, required this.calculate});
}
double v(Map<String,double> m, String k) => m[k] ?? 0;
double safeDiv(double a, double b) => b == 0 ? 0 : a / b;
double ceilDiv(double a, double b) => b <= 0 ? 0 : (a / b).ceilToDouble();

final List<CalcDef> calculators = [
  CalcDef(id:'concrete',title:'حجم الخرسانة',category:'الخرسانة',formula:'الطول × العرض × الارتفاع',note:'أدخل الأبعاد بالمتر. الناتج حجم هندسي قبل أي هالك أو زيادة تنفيذية.',resultUnit:'م³',fields:[CalcField('l','الطول','م'),CalcField('w','العرض','م'),CalcField('h','الارتفاع / السمك','م')],calculate:(m)=>v(m,'l')*v(m,'w')*v(m,'h')),
  CalcDef(id:'slab',title:'خرسانة بلاطة',category:'الخرسانة',formula:'المساحة × السمك',note:'لا يشمل الكمرات الساقطة أو الفتحات. اطرح الفتحات بشكل منفصل عند الحاجة.',resultUnit:'م³',fields:[CalcField('area','مساحة البلاطة','م²'),CalcField('t','السمك','م')],calculate:(m)=>v(m,'area')*v(m,'t')),
  CalcDef(id:'beam',title:'خرسانة كمرة',category:'الخرسانة',formula:'الطول × العرض × العمق',note:'للحصر الكمي فقط؛ انتبه لتداخل الكمرة مع البلاطة عند إعداد الحصر النهائي.',resultUnit:'م³',fields:[CalcField('l','الطول','م'),CalcField('b','العرض','م'),CalcField('d','العمق','م')],calculate:(m)=>v(m,'l')*v(m,'b')*v(m,'d')),
  CalcDef(id:'column',title:'خرسانة عمود',category:'الخرسانة',formula:'عدد الأعمدة × العرض × العمق × الارتفاع',note:'للأعمدة المستطيلة. للأعمدة الدائرية استخدم أداة الحجم العامة مع مساحة المقطع المناسبة.',resultUnit:'م³',fields:[CalcField('n','عدد الأعمدة','عدد'),CalcField('b','العرض','م'),CalcField('d','العمق','م'),CalcField('h','الارتفاع','م')],calculate:(m)=>v(m,'n')*v(m,'b')*v(m,'d')*v(m,'h')),
  CalcDef(id:'footing',title:'خرسانة قاعدة منفصلة',category:'الخرسانة',formula:'عدد القواعد × الطول × العرض × السمك',note:'لا يشمل رقاب الأعمدة أو خرسانة النظافة.',resultUnit:'م³',fields:[CalcField('n','عدد القواعد','عدد'),CalcField('l','الطول','م'),CalcField('w','العرض','م'),CalcField('t','السمك','م')],calculate:(m)=>v(m,'n')*v(m,'l')*v(m,'w')*v(m,'t')),
  CalcDef(id:'cyl',title:'خرسانة عنصر دائري',category:'الخرسانة',formula:'عدد العناصر × π × نصف القطر² × الارتفاع',note:'للأعمدة أو الخزانات الأسطوانية دون خصم أي فتحات.',resultUnit:'م³',fields:[CalcField('n','العدد','عدد'),CalcField('r','نصف القطر','م'),CalcField('h','الارتفاع','م')],calculate:(m)=>v(m,'n')*math.pi*math.pow(v(m,'r'),2)*v(m,'h')),
  CalcDef(id:'rebar',title:'وزن حديد التسليح',category:'الحديد',formula:'القطر² ÷ 162 × إجمالي الأطوال',note:'معادلة تقريبية شائعة لوزن المتر الطولي بالكيلوجرام، ولا تشمل الوصلات أو الهالك.',resultUnit:'كجم',fields:[CalcField('d','قطر السيخ','مم'),CalcField('l','إجمالي الأطوال','م')],calculate:(m)=>math.pow(v(m,'d'),2)/162*v(m,'l')),
  CalcDef(id:'bars',title:'عدد أسياخ التسليح',category:'الحديد',formula:'تقريب لأعلى: إجمالي الطول ÷ طول السيخ التجاري',note:'حساب أولي فقط؛ لا يقوم بتحسين التقطيع أو حساب أطوال التراكب والخطافات.',resultUnit:'سيخ',fields:[CalcField('l','إجمالي طول الحديد المطلوب','م'),CalcField('bar','طول السيخ التجاري','م',12)],calculate:(m)=>ceilDiv(v(m,'l'),v(m,'bar'))),
  CalcDef(id:'stirrups',title:'عدد الكانات',category:'الحديد',formula:'تقريب لأعلى: طول العنصر ÷ المسافة + 1',note:'حساب عددي مبسط. راجع مناطق تكثيف الكانات وأول/آخر كانة والتفاصيل الإنشائية.',resultUnit:'كانة',fields:[CalcField('l','طول العنصر','م'),CalcField('s','المسافة بين الكانات','م'),CalcField('n','عدد العناصر','عدد',1)],calculate:(m)=>(ceilDiv(v(m,'l'),v(m,'s'))+1)*v(m,'n')),
  CalcDef(id:'excavation',title:'حجم الحفر',category:'أعمال ترابية',formula:'الطول × العرض × العمق',note:'حجم هندسي نظري؛ لا يتضمن ميول جوانب الحفر أو الانتفاش.',resultUnit:'م³',fields:[CalcField('l','الطول','م'),CalcField('w','العرض','م'),CalcField('d','العمق','م')],calculate:(m)=>v(m,'l')*v(m,'w')*v(m,'d')),
  CalcDef(id:'trench',title:'حفر خندق / خط مواسير',category:'أعمال ترابية',formula:'الطول × عرض الخندق × العمق',note:'لا يشمل توسعات غرف التفتيش أو ميول جوانب الخندق.',resultUnit:'م³',fields:[CalcField('l','طول الخندق','م'),CalcField('w','عرض الخندق','م'),CalcField('d','العمق','م')],calculate:(m)=>v(m,'l')*v(m,'w')*v(m,'d')),
  CalcDef(id:'backfill',title:'حجم الردم الصافي',category:'أعمال ترابية',formula:'حجم الحفر − حجم المنشأ داخل الحفر',note:'أدخل الأحجام بالمتر المكعب. لا يطبق معامل دمك أو انتفاش تلقائياً.',resultUnit:'م³',fields:[CalcField('exc','حجم الحفر','م³'),CalcField('struct','حجم المنشأ داخل الحفر','م³')],calculate:(m)=>math.max(0,v(m,'exc')-v(m,'struct'))),
  CalcDef(id:'compaction',title:'كمية توريد ردم قبل الدمك',category:'أعمال ترابية',formula:'الحجم النهائي × معامل التوريد',note:'أدخل معامل التوريد من مواصفات المشروع أو نتائج الموقع؛ لا توجد قيمة افتراضية مفروضة.',resultUnit:'م³',fields:[CalcField('final','الحجم بعد الدمك','م³'),CalcField('factor','معامل التوريد','×',1)],calculate:(m)=>v(m,'final')*v(m,'factor')),
  CalcDef(id:'fill',title:'حجم طبقة إحلال / ردم',category:'أعمال ترابية',formula:'المساحة × السمك',note:'حجم هندسي مدموك إذا كانت الأبعاد تمثل المناسيب النهائية.',resultUnit:'م³',fields:[CalcField('area','المساحة','م²'),CalcField('t','السمك','م')],calculate:(m)=>v(m,'area')*v(m,'t')),
  CalcDef(id:'asphalt',title:'كمية الأسفلت بالطن',category:'الطرق',formula:'المساحة × السمك بالمتر × الكثافة طن/م³',note:'أدخل كثافة الخلطة التصميمية/المعتمدة من المشروع. لا تفترض كثافة ثابتة.',resultUnit:'طن',fields:[CalcField('area','المساحة','م²'),CalcField('t','السمك','سم'),CalcField('density','الكثافة','طن/م³',2.4)],calculate:(m)=>v(m,'area')*v(m,'t')/100*v(m,'density')),
  CalcDef(id:'roadarea',title:'مساحة طبقة طريق',category:'الطرق',formula:'الطول × العرض',note:'للحصر المساحي؛ اخصم التقاطعات أو الفتحات عند الحاجة.',resultUnit:'م²',fields:[CalcField('l','الطول','م'),CalcField('w','العرض','م')],calculate:(m)=>v(m,'l')*v(m,'w')),
  CalcDef(id:'curb',title:'طول البردورة',category:'الطرق',formula:'عدد القطع × طول القطعة',note:'لا يخصم الفواصل أو القطع المكسورة.',resultUnit:'م طولي',fields:[CalcField('n','عدد القطع','قطعة'),CalcField('l','طول القطعة','م',0.5)],calculate:(m)=>v(m,'n')*v(m,'l')),
  CalcDef(id:'slope',title:'ميل الطريق / خط المواسير',category:'الطرق',formula:'فرق المنسوب ÷ المسافة × 100',note:'استخدم نفس وحدة الطول للفرق والمسافة. الناتج نسبة مئوية.',resultUnit:'%',fields:[CalcField('dh','فرق المنسوب','م'),CalcField('l','المسافة الأفقية','م')],calculate:(m)=>safeDiv(v(m,'dh'),v(m,'l'))*100),
  CalcDef(id:'pipe',title:'حجم ماسورة أسطوانية',category:'المرافق',formula:'π × القطر الداخلي² ÷ 4 × الطول',note:'حجم داخلي نظري؛ أدخل القطر الداخلي بالمتر.',resultUnit:'م³',fields:[CalcField('d','القطر الداخلي','م'),CalcField('l','الطول','م')],calculate:(m)=>math.pi*math.pow(v(m,'d'),2)/4*v(m,'l')),
  CalcDef(id:'water',title:'حجم خزان مستطيل',category:'المرافق',formula:'الطول × العرض × الارتفاع',note:'حجم هندسي؛ لتر = متر مكعب × 1000.',resultUnit:'م³',fields:[CalcField('l','الطول','م'),CalcField('w','العرض','م'),CalcField('h','ارتفاع الماء','م')],calculate:(m)=>v(m,'l')*v(m,'w')*v(m,'h')),
  CalcDef(id:'blocks',title:'عدد البلوك التقريبي',category:'مباني وتشطيبات',formula:'مساحة الحائط ÷ مساحة وجه البلوكة',note:'أدخل أبعاد وجه البلوكة بالمتر. لا يشمل الفتحات أو الهالك أو اختلاف المونة.',resultUnit:'بلوك',fields:[CalcField('area','مساحة الحائط','م²'),CalcField('bw','عرض وجه البلوكة','م',0.4),CalcField('bh','ارتفاع وجه البلوكة','م',0.2),CalcField('waste','هالك %','%',5)],calculate:(m)=>ceilDiv(v(m,'area')*(1+v(m,'waste')/100),v(m,'bw')*v(m,'bh'))),
  CalcDef(id:'tile',title:'كمية البلاط مع الهالك',category:'مباني وتشطيبات',formula:'المساحة × (1 + الهالك%) ÷ مساحة البلاطة',note:'أدخل مساحة البلاطة بالمتر المربع. النتيجة عدد تقريبي مقرب لأعلى.',resultUnit:'بلاطة',fields:[CalcField('area','المساحة','م²'),CalcField('piece','مساحة البلاطة','م²',0.36),CalcField('waste','هالك %','%',7)],calculate:(m)=>ceilDiv(v(m,'area')*(1+v(m,'waste')/100),v(m,'piece'))),
  CalcDef(id:'paintarea',title:'مساحة الدهانات',category:'مباني وتشطيبات',formula:'إجمالي أطوال الحوائط × الارتفاع − الفتحات',note:'أدخل مساحة الفتحات المراد خصمها. لا يشمل الأسقف إلا إذا أضيفت كمساحة منفصلة.',resultUnit:'م²',fields:[CalcField('length','إجمالي أطوال الحوائط','م'),CalcField('h','الارتفاع','م'),CalcField('open','مساحة الفتحات','م²')],calculate:(m)=>math.max(0,v(m,'length')*v(m,'h')-v(m,'open'))),
  CalcDef(id:'paint',title:'كمية الدهان باللتر',category:'مباني وتشطيبات',formula:'المساحة × عدد الأوجه ÷ معدل التغطية',note:'معدل التغطية من بيانات الشركة المصنعة ويتأثر بالسطح وطريقة التطبيق.',resultUnit:'لتر',fields:[CalcField('area','المساحة','م²'),CalcField('coats','عدد الأوجه','وجه',2),CalcField('cover','معدل التغطية','م²/لتر',10)],calculate:(m)=>safeDiv(v(m,'area')*v(m,'coats'),v(m,'cover'))),
  CalcDef(id:'plaster',title:'حجم مونة المحارة',category:'مباني وتشطيبات',formula:'المساحة × السمك',note:'حجم نظري قبل معامل الخلط والهالك. لا يحدد نسب الأسمنت والرمل.',resultUnit:'م³',fields:[CalcField('area','المساحة','م²'),CalcField('t','السمك','سم',2)],calculate:(m)=>v(m,'area')*v(m,'t')/100),
  CalcDef(id:'screed',title:'حجم طبقة الميول / السكريد',category:'مباني وتشطيبات',formula:'المساحة × متوسط السمك',note:'استخدم متوسط السمك إذا كان السمك متغيراً.',resultUnit:'م³',fields:[CalcField('area','المساحة','م²'),CalcField('t','متوسط السمك','م')],calculate:(m)=>v(m,'area')*v(m,'t')),
  CalcDef(id:'cost',title:'تكلفة بند مقاولة',category:'التكاليف والعقود',formula:'الكمية × سعر الوحدة',note:'أدخل سعر الوحدة بعملة الدولة المختارة؛ لا يتم جلب أسعار سوقية تلقائياً.',resultUnit:'قيمة مالية',fields:[CalcField('q','الكمية','وحدة'),CalcField('price','سعر الوحدة','عملة')],calculate:(m)=>v(m,'q')*v(m,'price')),
  CalcDef(id:'tax',title:'إضافة ضريبة',category:'التكاليف والعقود',formula:'المبلغ × (1 + نسبة الضريبة ÷ 100)',note:'أدخل نسبة الضريبة الصحيحة حسب الدولة ونوع المعاملة وتاريخها.',resultUnit:'قيمة مالية',fields:[CalcField('amount','المبلغ قبل الضريبة','عملة'),CalcField('rate','نسبة الضريبة','%',0)],calculate:(m)=>v(m,'amount')*(1+v(m,'rate')/100)),
  CalcDef(id:'discount',title:'خصم / استقطاع',category:'التكاليف والعقود',formula:'المبلغ × نسبة الخصم ÷ 100',note:'الناتج قيمة الخصم فقط؛ اطرحها من المبلغ الأصلي للحصول على الصافي.',resultUnit:'قيمة مالية',fields:[CalcField('amount','المبلغ','عملة'),CalcField('rate','نسبة الخصم','%')],calculate:(m)=>v(m,'amount')*v(m,'rate')/100),
  CalcDef(id:'retention',title:'استقطاع ضمان الأعمال',category:'التكاليف والعقود',formula:'قيمة المستخلص × نسبة الاستقطاع ÷ 100',note:'النسبة والحد الأقصى وموعد الصرف طبقاً للعقد فقط.',resultUnit:'قيمة مالية',fields:[CalcField('amount','قيمة المستخلص','عملة'),CalcField('rate','نسبة الاستقطاع','%')],calculate:(m)=>v(m,'amount')*v(m,'rate')/100),
  CalcDef(id:'advance',title:'استرداد دفعة مقدمة',category:'التكاليف والعقود',formula:'قيمة المستخلص × نسبة الاسترداد ÷ 100',note:'آلية الاسترداد وحدوده طبقاً لشروط العقد.',resultUnit:'قيمة مالية',fields:[CalcField('amount','قيمة المستخلص','عملة'),CalcField('rate','نسبة الاسترداد','%')],calculate:(m)=>v(m,'amount')*v(m,'rate')/100),
  CalcDef(id:'productivity',title:'إنتاجية طاقم العمل',category:'إدارة الموقع',formula:'الكمية المنفذة ÷ عدد العمال ÷ عدد الأيام',note:'مؤشر متوسط للعامل في اليوم؛ قارن الأعمال المتشابهة وظروف التنفيذ.',resultUnit:'وحدة/عامل/يوم',fields:[CalcField('q','الكمية المنفذة','وحدة'),CalcField('workers','عدد العمال','عامل'),CalcField('days','عدد الأيام','يوم')],calculate:(m)=>safeDiv(v(m,'q'),v(m,'workers')*v(m,'days'))),
  CalcDef(id:'duration',title:'مدة تنفيذ تقديرية',category:'إدارة الموقع',formula:'الكمية ÷ الإنتاجية اليومية',note:'تقدير حسابي لا يتضمن التوقفات أو القيود أو التقويم الزمني.',resultUnit:'يوم',fields:[CalcField('q','الكمية المتبقية','وحدة'),CalcField('rate','الإنتاجية اليومية','وحدة/يوم')],calculate:(m)=>safeDiv(v(m,'q'),v(m,'rate'))),
];

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage> {
  int tab=0; String country='السعودية'; String query='';
  final pages = const ['الرئيسية','الحاسبات','المكتب الفني','الجودة والسلامة','الإعدادات'];
  @override Widget build(BuildContext context) {
    final currency = country=='السعودية'?'ريال سعودي (SAR)':'جنيه مصري (EGP)';
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('المهندس الذكي',style:TextStyle(fontWeight:FontWeight.bold)), actions:[Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:Center(child:Text(country,style:const TextStyle(fontSize:12))))]),
      body: IndexedStack(index:tab,children:[
        Dashboard(currency:currency,onOpen:(i)=>setState(()=>tab=i)),
        CalculatorCatalog(country:country,query:query,onQuery:(s)=>setState(()=>query=s)),
        const OfficePage(),
        const QualityPage(),
        SettingsPage(country:country,onCountry:(s)=>setState(()=>country=s),currency:currency),
      ]),
      bottomNavigationBar: NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const[
        NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'الرئيسية'),
        NavigationDestination(icon:Icon(Icons.calculate_outlined),selectedIcon:Icon(Icons.calculate),label:'الحاسبات'),
        NavigationDestination(icon:Icon(Icons.description_outlined),label:'المكتب الفني'),
        NavigationDestination(icon:Icon(Icons.fact_check_outlined),label:'الجودة'),
        NavigationDestination(icon:Icon(Icons.settings_outlined),label:'الإعدادات'),
      ]),
    ));
  }
}

class Dashboard extends StatelessWidget {
 final String currency; final ValueChanged<int> onOpen;
 const Dashboard({super.key,required this.currency,required this.onOpen});
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
  Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   const Text('أدواتك الهندسية في مكان واحد',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.bold)),
   const SizedBox(height:8),Text('حسابات كميات • طرق • خرسانة • حديد • مكتب فني',style:TextStyle(color:Colors.white.withOpacity(.8))),
   const SizedBox(height:14),Text('العملة الحالية: $currency',style:const TextStyle(color:gold,fontWeight:FontWeight.bold)),
  ])),
  const SizedBox(height:18),const Text('الأقسام الرئيسية',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
  const SizedBox(height:10),
  GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:1.45,children:[
   _tile(context,Icons.calculate,'الحاسبات الهندسية','أكثر من 30 أداة',()=>onOpen(1)),
   _tile(context,Icons.assignment,'المكتب الفني','تقارير ومستخلصات',()=>onOpen(2)),
   _tile(context,Icons.verified_user,'الجودة والسلامة','قوائم فحص وملاحظات',()=>onOpen(3)),
   _tile(context,Icons.tune,'إعدادات الدولة','السعودية ومصر',()=>onOpen(4)),
  ]),
  const SizedBox(height:18),const Text('إدارة المشروع والتصدير',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
  const SizedBox(height:8),
  Card(child:ListTile(leading:const Icon(Icons.folder_copy,color:navy),title:const Text('مشاريعي وحفظ البيانات'),subtitle:const Text('إنشاء مشاريع وحفظ بياناتها محلياً'),trailing:const Icon(Icons.chevron_left),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const ProjectsPage())))),
  Card(child:ListTile(leading:const Icon(Icons.price_change,color:navy),title:const Text('قاعدة أسعار البنود'),subtitle:const Text('إضافة وتعديل أسعارك حسب الدولة والمشروع'),trailing:const Icon(Icons.chevron_left),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const PriceBookPage())))),
  Card(child:ListTile(leading:const Icon(Icons.picture_as_pdf,color:navy),title:const Text('تصدير تقرير تجريبي'),subtitle:const Text('إنشاء PDF أو ملف Excel قابل للفتح في Excel'),trailing:const Icon(Icons.chevron_left),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const ExportPage())))),
  const SizedBox(height:18),const Card(child:Padding(padding:EdgeInsets.all(14),child:Text('تنبيه مهني: نتائج الحاسبات تقديرية للحصر والتخطيط. لا تستخدمها بديلاً عن التصميم المعتمد أو المخططات أو مواصفات المشروع أو مراجعة مهندس مختص.'))),
 ]);
 Widget _tile(BuildContext c,IconData icon,String title,String sub,VoidCallback fn)=>Card(child:InkWell(borderRadius:BorderRadius.circular(14),onTap:fn,child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:gold,size:28),const SizedBox(height:8),Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),Text(sub,style:const TextStyle(color:Colors.black54,fontSize:12))]))));
}

class CalculatorCatalog extends StatelessWidget {
 final String country,query; final ValueChanged<String> onQuery;
 const CalculatorCatalog({super.key,required this.country,required this.query,required this.onQuery});
 @override Widget build(BuildContext context){
  final cats=calculators.map((e)=>e.category).toSet().toList();
  final filtered=calculators.where((c)=>('${c.title} ${c.category}').contains(query)).toList();
  return Column(children:[
   Padding(padding:const EdgeInsets.all(12),child:TextField(onChanged:onQuery,decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'ابحث عن حاسبة...',filled:true,border:OutlineInputBorder()))),
   Expanded(child:ListView(children:[
    for(final cat in cats.where((c)=>filtered.any((e)=>e.category==c))) ...[
     Padding(padding:const EdgeInsets.fromLTRB(16,12,16,5),child:Text(cat,style:const TextStyle(fontWeight:FontWeight.bold,color:navy,fontSize:17))),
     ...filtered.where((e)=>e.category==cat).map((c)=>Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:4),child:ListTile(leading:const CircleAvatar(backgroundColor:Color(0xFFFFF2D8),child:Icon(Icons.calculate,color:navy)),title:Text(c.title),subtitle:Text(c.formula,maxLines:1,overflow:TextOverflow.ellipsis),trailing:const Icon(Icons.chevron_left),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CalcPage(def:c,country:country))))),
    ]
   ]))
  ]);
 }
}

class CalcPage extends StatefulWidget { final CalcDef def; final String country; const CalcPage({super.key,required this.def,required this.country}); @override State<CalcPage> createState()=>_CalcPageState(); }
class _CalcPageState extends State<CalcPage>{
 late final Map<String,TextEditingController> ctrls;
 double? result; String get currency=>widget.country=='السعودية'?'SAR':'EGP';
 @override void initState(){super.initState();ctrls={for(final f in widget.def.fields)f.keyName:TextEditingController(text:f.initial==0?'':f.initial.toString())};}
 @override void dispose(){for(final c in ctrls.values)c.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:Text(widget.def.title)),body:ListView(padding:const EdgeInsets.all(16),children:[
  Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('المعادلة',style:TextStyle(fontWeight:FontWeight.bold,color:navy)),const SizedBox(height:6),Text(widget.def.formula),const SizedBox(height:8),Text(widget.def.note,style:const TextStyle(color:Colors.black54,fontSize:12))]))),
  const SizedBox(height:10),
  ...widget.def.fields.map((f)=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:ctrls[f.keyName],keyboardType:const TextInputType.numberWithOptions(decimal:true,signed:false),decoration:InputDecoration(labelText:f.label,suffixText:f.unit,border:const OutlineInputBorder())))),
  FilledButton.icon(onPressed:(){final m=<String,double>{};for(final f in widget.def.fields){m[f.keyName]=double.tryParse(ctrls[f.keyName]!.text.replaceAll(',','.'))??0;}setState(()=>result=widget.def.calculate(m));},icon:const Icon(Icons.calculate),label:const Text('احسب النتيجة')),
  if(result!=null) Card(color:const Color(0xFFE8F2EC),child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[const Text('النتيجة',style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:6),Text('${result!.toStringAsFixed(3)} ${widget.def.resultUnit=='قيمة مالية'?currency:widget.def.resultUnit}',style:const TextStyle(fontSize:25,fontWeight:FontWeight.bold,color:navy))]))),
  const Text('راجع الوحدات والمدخلات قبل اعتماد الناتج في الحصر أو المستخلص.',style:TextStyle(color:Colors.black54,fontSize:12)),
 ])));
}

class OfficePage extends StatelessWidget {
 const OfficePage({super.key});
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(14),children:[
  const Text('أدوات المكتب الفني',style:TextStyle(fontWeight:FontWeight.bold,fontSize:20)),
  const SizedBox(height:10),
  const OfficeTemplate(title:'تقرير يومي للموقع',description:'نموذج نصي قابل للتعبئة والنسخ يضم العمالة والمعدات والأعمال والمعوقات.',fields:['التاريخ','اسم المشروع','الموقع / القطاع','الأعمال المنفذة والكميات','عدد العمالة','المعدات العاملة','المواد المستلمة','الفحوصات والاختبارات','المعوقات والإجراءات','ملاحظات المهندس']),
  const OfficeTemplate(title:'محضر استلام بند',description:'قائمة بنود تحقق قبل طلب الاستلام.',fields:['اسم البند وموقعه','مطابقة المخططات المعتمدة','مطابقة المواصفات','الأبعاد والمناسيب','نتائج الاختبارات','الملاحظات','الإجراء المطلوب']),
  const OfficeTemplate(title:'طلب فحص أعمال (WIR)',description:'بيانات طلب فحص الأعمال قبل تغطيتها أو الانتقال للمرحلة التالية.',fields:['رقم الطلب','التاريخ والوقت','المقاول','البند والموقع','المرجع / المخطط','نقاط الفحص','المرفقات','نتيجة الفحص']),
  const OfficeTemplate(title:'تقرير عدم مطابقة (NCR)',description:'تسجيل الحالة والإجراء التصحيحي والتحقق من الإغلاق.',fields:['رقم NCR','وصف عدم المطابقة','الموقع والتاريخ','المرجع التعاقدي','الإجراء الفوري','تحليل السبب الجذري','الإجراء التصحيحي','مسؤول التنفيذ','موعد الإغلاق','نتيجة التحقق']),
  const OfficeTemplate(title:'حصر كميات ومستخلص',description:'نموذج تنظيم بيانات البند والقياس والمرفقات.',fields:['رقم البند','وصف البند','الوحدة','الكمية السابقة','كمية الفترة الحالية','الإجمالي التراكمي','السعر التعاقدي','مرجع القياس','المرفقات']),
  const OfficeTemplate(title:'طلب معلومات فنية (RFI)',description:'تسجيل الاستفسار الفني والمرجع والرد المطلوب.',fields:['رقم RFI','التاريخ','الموقع / البند','مرجع المخطط والمواصفة','وصف الاستفسار','الأثر المحتمل','الرد والاعتماد']),
 ]);
}

class OfficeTemplate extends StatefulWidget {
 final String title,description; final List<String> fields;
 const OfficeTemplate({super.key,required this.title,required this.description,required this.fields});
 @override State<OfficeTemplate> createState()=>_OfficeTemplateState();
}
class _OfficeTemplateState extends State<OfficeTemplate>{
 late final Map<String,TextEditingController> c;
 @override void initState(){super.initState();c={for(final f in widget.fields)f:TextEditingController()};}
 @override void dispose(){for(final x in c.values)x.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Card(child:ExpansionTile(title:Text(widget.title,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text(widget.description),children:[
  Padding(padding:const EdgeInsets.all(12),child:Column(children:[
   ...widget.fields.map((f)=>Padding(padding:const EdgeInsets.only(bottom:8),child:TextField(controller:c[f],maxLines:2,decoration:InputDecoration(labelText:f,border:const OutlineInputBorder())))),
   FilledButton.icon(onPressed:(){final out=widget.fields.map((f)=>'$f: ${c[f]!.text}').join('\n');showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('النموذج المكتمل'),content:SingleChildScrollView(child:SelectableText(out)),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إغلاق'))]));},icon:const Icon(Icons.preview),label:const Text('معاينة النموذج')),
  ]))
 ]));
}

class QualityPage extends StatelessWidget {
 const QualityPage({super.key});
 final groups=const <String,List<String>>{
  'استلام أعمال خرسانية':['مطابقة الأبعاد والمحاور','مراجعة الشدة والدعائم','مراجعة الغطاء الخرساني','مطابقة التسليح والقطر والعدد','نظافة القالب قبل الصب','اعتماد طلب الفحص','توثيق نتائج اختبار الخرسانة والمعالجة'],
  'أعمال الطرق والأسفلت':['اعتماد مصدر المواد والخلطة','فحص طبقة الأساس والمناسيب','قياس درجات الحرارة حسب المواصفة','فحص سمك الطبقة والكثافة','توثيق نتائج الكور والاختبارات','فحص الاستواء والميول'],
  'السلامة بالموقع':['حواجز وتحويلات مرورية مناسبة','معدات الوقاية الشخصية','تصاريح العمل المطلوبة','تأمين الحفريات والحواف','سلامة المعدات ومسارات الحركة','خطة الطوارئ والإسعافات'],
  'استلام أعمال تشطيبات':['مطابقة العينة واللون','استواء السطح والمناسيب','فحص الفواصل والترويب','معالجة العيوب قبل التسليم','حماية الأعمال المنفذة'],
 };
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(14),children:[
  const Text('قوائم الفحص والجودة',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
  const Padding(padding:EdgeInsets.symmetric(vertical:8),child:Text('ضع علامة على النقاط التي تم التحقق منها. القائمة مساعدة ولا تستبدل خطة الفحص والاختبار المعتمدة ITP.')),
  ...groups.entries.map((e)=>ChecklistCard(title:e.key,items:e.value)),
 ]);
}
class ChecklistCard extends StatefulWidget {final String title;final List<String> items;const ChecklistCard({super.key,required this.title,required this.items});@override State<ChecklistCard> createState()=>_ChecklistCardState();}
class _ChecklistCardState extends State<ChecklistCard>{late List<bool> checks;@override void initState(){super.initState();checks=List.filled(widget.items.length,false);}@override Widget build(BuildContext context)=>Card(child:ExpansionTile(title:Text(widget.title),subtitle:Text('${checks.where((x)=>x).length} / ${checks.length} مكتمل'),children:widget.items.asMap().entries.map((e)=>CheckboxListTile(value:checks[e.key],onChanged:(x)=>setState(()=>checks[e.key]=x??false),title:Text(e.value),controlAffinity:ListTileControlAffinity.leading)).toList()));}

class SettingsPage extends StatelessWidget {
 final String country,currency; final ValueChanged<String> onCountry;
 const SettingsPage({super.key,required this.country,required this.onCountry,required this.currency});
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
  const Text('الإعدادات',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
  Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   const Text('الدولة والعملة',style:TextStyle(fontWeight:FontWeight.bold)),
   RadioListTile<String>(value:'السعودية',groupValue:country,onChanged:(x)=>onCountry(x!),title:const Text('السعودية — SAR')),
   RadioListTile<String>(value:'مصر',groupValue:country,onChanged:(x)=>onCountry(x!),title:const Text('مصر — EGP')),
   Text('العملة المستخدمة في عرض نتائج التكلفة: $currency'),
  ]))),
  const Card(child:Padding(padding:EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('حدود التطبيق',style:TextStyle(fontWeight:FontWeight.bold)),
   SizedBox(height:8),
   Text('• الأسعار تُدخل يدوياً ولا توجد قاعدة أسعار سوقية مباشرة.\n• النماذج لا تحفظ البيانات بعد إغلاق التطبيق في هذه النسخة.\n• لا يوجد تسجيل دخول أو مزامنة سحابية أو تصدير PDF حالياً.\n• لا يوجد ربط تلقائي بكود البناء السعودي أو الكود المصري.\n• لا تستخدم الحاسبات لتصميم أو اعتماد عناصر إنشائية.'),
  ]))),
  const Card(child:Padding(padding:EdgeInsets.all(14),child:Text('الإصدار 1.0 — نسخة تشغيل أولية قابلة للتطوير. يجب مراجعة الحسابات ومطابقتها مع مستندات المشروع قبل الاستخدام الرسمي.'))),
 ]);
}


class LocalStore {
 static const projectsKey='smart_engineer_projects_v1';
 static const pricesKey='smart_engineer_prices_v1';
 static Future<List<Map<String,dynamic>>> read(String key) async {
  final p=await SharedPreferences.getInstance(); final raw=p.getString(key);
  if(raw==null)return [];
  try{return (jsonDecode(raw) as List).map((e)=>Map<String,dynamic>.from(e)).toList();}catch(_){return [];}
 }
 static Future<void> write(String key,List<Map<String,dynamic>> rows) async {
  final p=await SharedPreferences.getInstance(); await p.setString(key,jsonEncode(rows));
 }
}

class ProjectsPage extends StatefulWidget {const ProjectsPage({super.key});@override State<ProjectsPage> createState()=>_ProjectsPageState();}
class _ProjectsPageState extends State<ProjectsPage>{
 List<Map<String,dynamic>> rows=[];bool loading=true;
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{rows=await LocalStore.read(LocalStore.projectsKey);if(mounted)setState(()=>loading=false);}
 Future<void> _add()async{
  final name=TextEditingController(), client=TextEditingController(), location=TextEditingController();
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('مشروع جديد'),content:Column(mainAxisSize:MainAxisSize.min,children:[
   TextField(controller:name,decoration:const InputDecoration(labelText:'اسم المشروع')),
   TextField(controller:client,decoration:const InputDecoration(labelText:'المالك / العميل')),
   TextField(controller:location,decoration:const InputDecoration(labelText:'الموقع')),
  ]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حفظ'))]));
  if(ok==true&&name.text.trim().isNotEmpty){rows.add({'name':name.text.trim(),'client':client.text,'location':location.text,'created':DateTime.now().toIso8601String()});await LocalStore.write(LocalStore.projectsKey,rows);setState((){});}
 }
 Future<void> _delete(int i)async{rows.removeAt(i);await LocalStore.write(LocalStore.projectsKey,rows);setState((){});}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('مشاريعي')),floatingActionButton:FloatingActionButton(onPressed:_add,child:const Icon(Icons.add)),body:loading?const Center(child:CircularProgressIndicator()):rows.isEmpty?const Center(child:Text('لا توجد مشاريع بعد. اضغط + لإضافة مشروع.')):ListView(children:rows.asMap().entries.map((e)=>Card(child:ListTile(leading:const Icon(Icons.folder,color:gold),title:Text(e.value['name']??''),subtitle:Text('${e.value['client']??''} • ${e.value['location']??''}'),trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>_delete(e.key))))).toList()));
}

class PriceBookPage extends StatefulWidget {const PriceBookPage({super.key});@override State<PriceBookPage> createState()=>_PriceBookPageState();}
class _PriceBookPageState extends State<PriceBookPage>{
 List<Map<String,dynamic>> rows=[];bool loading=true;String country='السعودية';
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{rows=await LocalStore.read(LocalStore.pricesKey);if(mounted)setState(()=>loading=false);}
 Future<void> _add()async{
  final item=TextEditingController(),unit=TextEditingController(),price=TextEditingController();
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('إضافة سعر بند'),content:Column(mainAxisSize:MainAxisSize.min,children:[
   TextField(controller:item,decoration:const InputDecoration(labelText:'اسم البند')),
   TextField(controller:unit,decoration:const InputDecoration(labelText:'الوحدة')),
   TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'سعر الوحدة')),
   DropdownButtonFormField<String>(value:country,decoration:const InputDecoration(labelText:'الدولة'),items:const [DropdownMenuItem(value:'السعودية',child:Text('السعودية SAR')),DropdownMenuItem(value:'مصر',child:Text('مصر EGP'))],onChanged:(v){if(v!=null)country=v;}),
  ]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حفظ'))]));
  if(ok==true&&item.text.trim().isNotEmpty){rows.add({'item':item.text,'unit':unit.text,'price':double.tryParse(price.text)??0,'country':country,'updated':DateTime.now().toIso8601String()});await LocalStore.write(LocalStore.pricesKey,rows);setState((){});}
 }
 Future<void> _remove(int i)async{rows.removeAt(i);await LocalStore.write(LocalStore.pricesKey,rows);setState((){});}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('قاعدة أسعار البنود')),floatingActionButton:FloatingActionButton(onPressed:_add,child:const Icon(Icons.add)),body:loading?const Center(child:CircularProgressIndicator()):rows.isEmpty?const Center(child:Text('أضف أسعار البنود من واقع عروض الأسعار والعقود.')):ListView(children:rows.asMap().entries.map((e)=>Card(child:ListTile(title:Text(e.value['item']??''),subtitle:Text('${e.value['unit']??''} • ${e.value['country']??''}'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text('${e.value['price']}'),IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>_remove(e.key))])))).toList()));
}

class ExportPage extends StatefulWidget {const ExportPage({super.key});@override State<ExportPage> createState()=>_ExportPageState();}
class _ExportPageState extends State<ExportPage>{
 final title=TextEditingController(text:'تقرير هندسي'),content=TextEditingController(text:'اسم المشروع:\nالتاريخ:\nالأعمال المنفذة:\nالكميات:\nالملاحظات:\n'),currency='SAR';
 @override void dispose(){title.dispose();content.dispose();super.dispose();}
 Future<void> _pdf()async{
  final doc=pw.Document();doc.addPage(pw.Page(build:(c)=>pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[pw.Text(title.text,style:pw.TextStyle(fontSize:22,fontWeight:pw.FontWeight.bold)),pw.SizedBox(height:20),pw.Text(content.text)])));
  await Printing.layoutPdf(onLayout:(format)=>doc.save());
 }
 Future<void> _excel()async{
  final book=Excel.createExcel();final sheet=book['Report'];
  sheet.appendRow([TextCellValue(title.text)]);
  for(final line in content.text.split('\n')){final parts=line.split(':');sheet.appendRow([TextCellValue(parts.first),TextCellValue(parts.length>1?parts.sublist(1).join(':').trim():'')]);}
  final bytes=book.encode();if(bytes==null)return;
  final file= XFile.fromData(bytes,name:'smart_engineer_report.xlsx',mimeType:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  await Share.shareXFiles([file],text:'تقرير من تطبيق المهندس الذكي');
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('تصدير التقارير')),body:ListView(padding:const EdgeInsets.all(16),children:[
  TextField(controller:title,decoration:const InputDecoration(labelText:'عنوان التقرير',border:OutlineInputBorder())),
  const SizedBox(height:10),TextField(controller:content,maxLines:14,decoration:const InputDecoration(labelText:'محتوى التقرير',alignLabelWithHint:true,border:OutlineInputBorder())),
  const SizedBox(height:12),FilledButton.icon(onPressed:_pdf,icon:const Icon(Icons.picture_as_pdf),label:const Text('إنشاء / طباعة PDF')),
  OutlinedButton.icon(onPressed:_excel,icon:const Icon(Icons.table_view),label:const Text('تصدير Excel')),
  const Padding(padding:EdgeInsets.only(top:10),child:Text('التصدير يعتمد على النص الذي تدخله هنا. لا يتم حالياً سحب كل بيانات المشروع تلقائياً إلى التقرير.',style:TextStyle(color:Colors.black54,fontSize:12))),
 ]));
}
