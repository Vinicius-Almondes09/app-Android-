import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();

  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({
    super.key,
    required this.cameras,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Detector de Objetos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
      ),
      home: DetectorPage(cameras: cameras),
    );
  }
}

class DetectorPage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const DetectorPage({
    super.key,
    required this.cameras,
  });

  @override
  State<DetectorPage> createState() => _DetectorPageState();
}

class _DetectorPageState extends State<DetectorPage> {
  CameraController? _cameraController;

  final TextEditingController _ipController = TextEditingController();

  final TextEditingController _portaController =
      TextEditingController(text: '5000');

  Uint8List? _imagemCapturada;

  String _resultado = 'Aguardando análise...';

  bool _analisando = false;

  @override
  void initState() {
    super.initState();
    _iniciarCamera();
  }

  Future<void> _iniciarCamera() async {
    if (widget.cameras.isEmpty) {
      setState(() {
        _resultado = 'Nenhuma câmera encontrada.';
      });
      return;
    }

    _cameraController = CameraController(
      widget.cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _resultado = 'Erro ao iniciar a câmera.';
        });
      }
    }
  }

  Future<Uint8List> _prepararImagem(Uint8List bytes) async {
    img.Image? imagem = img.decodeImage(bytes);

    if (imagem == null) {
      throw Exception('Não foi possível processar a imagem.');
    }

    imagem = img.bakeOrientation(imagem);

    if (imagem.width > 1280) {
      imagem = img.copyResize(
        imagem,
        width: 1280,
      );
    }

    return Uint8List.fromList(
      img.encodeJpg(
        imagem,
        quality: 80,
      ),
    );
  }

  Future<String> _enviarImagem(
    Uint8List imagem,
    String ip,
    int porta,
  ) async {
    Socket? socket;

    try {
      socket = await Socket.connect(
        ip,
        porta,
        timeout: const Duration(seconds: 10),
      );

      final cabecalho = ByteData(4);

      cabecalho.setUint32(
        0,
        imagem.length,
        Endian.big,
      );

      socket.add(cabecalho.buffer.asUint8List());
      socket.add(imagem);

      await socket.flush();

      final dadosResposta = await socket.toList();

      final resposta = utf8.decode(
        dadosResposta.expand((dados) => dados).toList(),
      );

      return resposta;
    } finally {
      socket?.destroy();
    }
  }

  Future<void> _tirarEAnalisar() async {
    final ip = _ipController.text.trim();

    final porta = int.tryParse(
      _portaController.text.trim(),
    );

    if (ip.isEmpty || porta == null) {
      setState(() {
        _resultado = 'Informe o IP e a porta corretamente.';
      });

      return;
    }

    if (_cameraController == null ||
        !_cameraController!.value.isInitialized) {
      setState(() {
        _resultado = 'A câmera ainda não está pronta.';
      });

      return;
    }

    setState(() {
      _analisando = true;
      _resultado = 'Analisando...';
    });

    try {
      final XFile foto =
          await _cameraController!.takePicture();

      final bytesOriginais =
          await foto.readAsBytes();

      final imagem =
          await _prepararImagem(bytesOriginais);

      if (mounted) {
        setState(() {
          _imagemCapturada = imagem;
        });
      }

      final resposta = await _enviarImagem(
        imagem,
        ip,
        porta,
      );

      if (mounted) {
        setState(() {
          _resultado = _formatarResultado(resposta);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _resultado =
              'Erro ao realizar a análise: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _analisando = false;
        });
      }
    }
  }

  String _formatarResultado(String resposta) {
    if (resposta.trim().isEmpty ||
        resposta.trim() == 'Nada Detectado') {
      return 'Nada Detectado';
    }

    final nomes = {
      'person': 'Pessoa',
      'car': 'Carro',
      'chair': 'Cadeira',
      'backpack': 'Mochila',
    };

    final objetos = resposta.split(',');

    return objetos.map((objeto) {
      final nome = objeto.trim();

      final traduzido = nomes[nome] ?? nome;

      return '$traduzido detectado';
    }).join('\n');
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _ipController.dispose();
    _portaController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraPronta =
        _cameraController?.value.isInitialized ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detector de Objetos',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ipController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'IP do servidor',
                hintText: 'Ex.: 192.168.0.105',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _portaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Porta',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            if (cameraPronta)
              AspectRatio(
                aspectRatio:
                    _cameraController!.value.aspectRatio,
                child: CameraPreview(
                  _cameraController!,
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _analisando ? null : _tirarEAnalisar,
                icon: const Icon(Icons.camera_alt),
                label: Text(
                  _analisando
                      ? 'Analisando...'
                      : 'Tirar e Analisar',
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (_imagemCapturada != null) ...[
              const Text(
                'Imagem capturada',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Image.memory(
                _imagemCapturada!,
                height: 200,
              ),

              const SizedBox(height: 20),
            ],

            const Text(
              'Resultado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _resultado,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}