import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';

/// Tipo de documento legal disponible.
enum LegalDocType { terms, privacy }

/// Página completa que muestra Términos y Condiciones o Política de Privacidad.
/// Uso:
///   LegalPageWidget.show(context, LegalDocType.terms);
///   LegalPageWidget.show(context, LegalDocType.privacy);
class LegalPageWidget extends StatelessWidget {
  final LegalDocType type;

  const LegalPageWidget({super.key, required this.type});

  static void show(BuildContext context, LegalDocType type) {
    final route = type == LegalDocType.terms ? '/terms' : '/privacy';
    Navigator.of(context).pushNamed(route);
  }

  String get _title => type == LegalDocType.terms
      ? 'Términos y Condiciones'
      : 'Política de Privacidad';

  IconData get _icon => type == LegalDocType.terms
      ? Icons.gavel_rounded
      : Icons.privacy_tip_outlined;

  List<_LegalSection> get _sections =>
      type == LegalDocType.terms ? _termsSections : _privacySections;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppColors.primaryLogo,
          foregroundColor: Colors.white,
          leading: const BackButton(),
          title: Row(
            children: [
              Icon(_icon, size: 20),
              const SizedBox(width: 10),
              Text(
                _title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // Fecha de vigencia
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: AppColors.mediumGray,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Última actualización: 17 de abril de 2026',
                    style: TextStyle(fontSize: 11, color: AppColors.mediumGray),
                  ),
                ],
              ),
            ),
            Divider(
              color: AppColors.greyOverlay.withValues(alpha: 0.4),
              height: 1,
              indent: 20,
              endIndent: 20,
            ),

            // Contenido
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                itemCount: _sections.length,
                itemBuilder: (_, i) => _SectionTile(section: _sections[i]),
              ),
            ),

            // Pie
            Container(
              color: AppColors.primaryLogo,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              width: double.infinity,
              child: const Text(
                '© 2026 Bazar & Tienda Nicole · Todos los derechos reservados',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tile de sección ──────────────────────────────────────────────────────────

class _SectionTile extends StatefulWidget {
  final _LegalSection section;
  const _SectionTile({required this.section});

  @override
  State<_SectionTile> createState() => _SectionTileState();
}

class _SectionTileState extends State<_SectionTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: AppColors.lightWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.greyOverlay.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          onExpansionChanged: (v) => setState(() => _expanded = v),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                widget.section.number,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
          ),
          title: Text(
            widget.section.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGray,
            ),
          ),
          trailing: Icon(
            _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            color: AppColors.primaryBlue,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                widget.section.content,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mediumGray,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modelo interno ───────────────────────────────────────────────────────────

class _LegalSection {
  final String number;
  final String title;
  final String content;
  const _LegalSection(this.number, this.title, this.content);
}

// ── Contenido: Términos y Condiciones ────────────────────────────────────────

const List<_LegalSection> _termsSections = [
  _LegalSection(
    '01',
    'Aceptación de los términos',
    'Al acceder y utilizar el catálogo web de Bazar & Tienda Nicole (en adelante "el Sitio"), usted acepta cumplir y quedar vinculado a los presentes Términos y Condiciones. Si no está de acuerdo con alguna parte de estos términos, le pedimos que no utilice el Sitio.',
  ),
  _LegalSection(
    '02',
    'Descripción del servicio',
    'El Sitio tiene carácter informativo y muestra los productos disponibles en nuestro establecimiento físico ubicado en Ecuador. Los precios, disponibilidad y características de los productos pueden variar sin previo aviso. El catálogo no constituye una oferta de venta electrónica.',
  ),
  _LegalSection(
    '03',
    'Propiedad intelectual',
    'Todos los contenidos del Sitio —incluyendo textos, imágenes, logotipos, diseño y código fuente— son propiedad de Bazar & Tienda Nicole o de sus respectivos propietarios y están protegidos por las leyes de propiedad intelectual vigentes en Ecuador. Queda prohibida su reproducción total o parcial sin autorización expresa.',
  ),
  _LegalSection(
    '04',
    'Uso permitido',
    'El Sitio está destinado exclusivamente para consulta de productos con fines personales y no comerciales. Queda prohibido:\n• Copiar, distribuir o comercializar el contenido del Sitio.\n• Realizar ingeniería inversa del software.\n• Utilizar el Sitio para actividades ilegales o que perjudiquen a terceros.\n• Enviar comunicaciones no solicitadas (spam).',
  ),
  _LegalSection(
    '05',
    'Exactitud de la información',
    'Bazar & Tienda Nicole realiza todos los esfuerzos razonables para mantener la información del catálogo actualizada y precisa. Sin embargo, no garantizamos que toda la información esté libre de errores. Ante cualquier discrepancia, la información del establecimiento físico prevalece.',
  ),
  _LegalSection(
    '06',
    'Limitación de responsabilidad',
    'En la máxima medida permitida por la ley ecuatoriana, Bazar & Tienda Nicole no será responsable por daños directos, indirectos, incidentales o consecuentes derivados del uso o la imposibilidad de usar el Sitio, incluyendo pérdidas de datos o interrupciones del servicio.',
  ),
  _LegalSection(
    '07',
    'Enlaces a terceros',
    'El Sitio puede contener enlaces a sitios de terceros. Bazar & Tienda Nicole no controla ni respalda el contenido de dichos sitios y no asume responsabilidad alguna por sus prácticas o contenidos.',
  ),
  _LegalSection(
    '08',
    'Modificaciones',
    'Nos reservamos el derecho de modificar estos Términos y Condiciones en cualquier momento. Los cambios entran en vigor en el momento de su publicación en el Sitio. Le recomendamos revisar periódicamente esta sección.',
  ),
  _LegalSection(
    '09',
    'Legislación aplicable',
    'Estos Términos y Condiciones se rigen e interpretan de conformidad con las leyes de la República del Ecuador. Cualquier disputa que surja en relación con estos términos se someterá a la jurisdicción de los tribunales competentes del Ecuador.',
  ),
  _LegalSection(
    '10',
    'Contacto',
    'Para consultas relacionadas con estos Términos y Condiciones puede comunicarse con nosotros a través de los canales de atención habilitados en nuestro establecimiento o mediante los medios de contacto disponibles en el catálogo.',
  ),
];

// ── Contenido: Política de Privacidad ────────────────────────────────────────

const List<_LegalSection> _privacySections = [
  _LegalSection(
    '01',
    'Responsable del tratamiento',
    'Bazar & Tienda Nicole, con domicilio en Ecuador, es responsable del tratamiento de los datos personales que usted proporcione al interactuar con este Sitio, de conformidad con la Ley Orgánica de Protección de Datos Personales (LOPDP) y su reglamento.',
  ),
  _LegalSection(
    '02',
    'Datos que recopilamos',
    'El presente catálogo web es de carácter informativo y no requiere registro ni inicio de sesión. Sin embargo, de manera automática pueden registrarse:\n• Dirección IP y datos de navegación (proveedor de internet, navegador, sistema operativo).\n• Cookies de sesión técnicas necesarias para el funcionamiento del Sitio.\n• Datos de acceso generados por servicios de alojamiento (Firebase / Google Cloud).',
  ),
  _LegalSection(
    '03',
    'Finalidad del tratamiento',
    'Los datos recopilados se utilizan exclusivamente para:\n• Garantizar el correcto funcionamiento técnico del Sitio.\n• Analizar el tráfico de manera agregada y anónima para mejorar la experiencia del usuario.\n• Cumplir con obligaciones legales aplicables.',
  ),
  _LegalSection(
    '04',
    'Uso de cookies',
    'Utilizamos cookies técnicas imprescindibles para el funcionamiento del Sitio. No utilizamos cookies de publicidad ni seguimiento de terceros. Al continuar navegando acepta el uso de estas cookies esenciales. Puede configurar su navegador para rechazar las cookies, aunque ello podría afectar la funcionalidad del Sitio.',
  ),
  _LegalSection(
    '05',
    'Compartición de datos',
    'No vendemos, alquilamos ni compartimos sus datos personales con terceros con fines comerciales. Los datos pueden ser accedidos únicamente por:\n• Personal autorizado de Bazar & Tienda Nicole.\n• Proveedores de servicios técnicos (p.ej. Google Firebase) sujetos a contratos de confidencialidad y políticas de privacidad propias.',
  ),
  _LegalSection(
    '06',
    'Transferencias internacionales',
    'El Sitio está alojado en infraestructura de Google Cloud/Firebase, cuyos servidores pueden estar ubicados fuera del Ecuador. Google LLC cuenta con certificaciones y marcos de protección de datos reconocidos internacionalmente que garantizan un nivel adecuado de protección.',
  ),
  _LegalSection(
    '07',
    'Conservación de datos',
    'Los datos de navegación se conservan durante el tiempo mínimo necesario para las finalidades descritas y, en ningún caso, más del período exigido por la legislación ecuatoriana vigente. Transcurrido dicho plazo, los datos son eliminados o anonimizados de forma segura.',
  ),
  _LegalSection(
    '08',
    'Derechos del titular',
    'De conformidad con la LOPDP, usted tiene derecho a:\n• Acceder a sus datos personales.\n• Rectificar datos inexactos o incompletos.\n• Solicitar la eliminación de sus datos.\n• Oponerse al tratamiento.\n• Portabilidad de los datos.\nPara ejercer estos derechos, contáctenos a través de los medios habilitados en nuestro establecimiento.',
  ),
  _LegalSection(
    '09',
    'Seguridad',
    'Implementamos medidas técnicas y organizativas apropiadas para proteger sus datos contra acceso no autorizado, alteración, divulgación o destrucción. No obstante, ningún sistema de transmisión por internet es 100 % seguro, por lo que no podemos garantizar la seguridad absoluta de la información.',
  ),
  _LegalSection(
    '10',
    'Menores de edad',
    'El Sitio no está dirigido a menores de 14 años y no recopilamos conscientemente datos personales de menores. Si usted es padre, madre o tutor y cree que su hijo ha proporcionado datos personales, contáctenos para proceder a su eliminación.',
  ),
  _LegalSection(
    '11',
    'Cambios en esta política',
    'Podemos actualizar esta Política de Privacidad periódicamente. Notificaremos los cambios significativos publicando la nueva versión en el Sitio con la fecha de última actualización. Le recomendamos revisarla con regularidad.',
  ),
  _LegalSection(
    '12',
    'Contacto',
    'Para cualquier consulta, solicitud o reclamación relacionada con la protección de sus datos personales puede contactarnos a través de los canales de atención disponibles en nuestro establecimiento físico o mediante los medios indicados en este catálogo.',
  ),
];
