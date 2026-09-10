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

// Etapas da comunicação com o servidor. Saber onde a
// falha aconteceu ajuda a apontar a causa correta.
enum ConnectStage {
  // Abrir o socket TCP (falha aqui costuma ser rede,
  // IP/porta errado ou firewall).
  conexao,

  // Enviar cabeçalho + bytes da imagem.
  envio,

  // Esperar o servidor processar (YOLO) e responder.
  resposta,
}

// Exceção que carrega a etapa da falha e o erro original.
class AnaliseException implements Exception {
  final ConnectStage etapa;

  final Object erro;

  const AnaliseException(this.etapa, this.erro);

  @override
  String toString() => '$erro';
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
      TextEditingController(text: '8080');

  Uint8List? _imagemCapturada;

  String _resultado = 'Aguardando análise...';

  bool _analisando = false;

  bool _procurando = false;

  bool _testandoConexao = false;

  // Verdadeiro enquanto qualquer operação de rede está
  // em andamento (usado para travar os botões).
  bool get _ocupado =>
      _analisando || _procurando || _testandoConexao;

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
    ConnectStage etapa = ConnectStage.conexao;

    Socket? socket;

    try {
      socket = await Socket.connect(
        ip,
        porta,
        timeout: const Duration(seconds: 10),
      );

      etapa = ConnectStage.envio;

      final cabecalho = ByteData(4);

      cabecalho.setUint32(
        0,
        imagem.length,
        Endian.big,
      );

      socket.add(cabecalho.buffer.asUint8List());
      socket.add(imagem);

      await socket.flush();

      etapa = ConnectStage.resposta;

      // O servidor só fecha o socket após devolver a
      // resposta, então 'toList()' encerra quando a
      // resposta completa chega. O timeout evita que o
      // app fique preso para sempre se o servidor
      // morrer no meio da análise.
      final dadosResposta = await socket
          .toList()
          .timeout(const Duration(seconds: 60));

      final resposta = utf8.decode(
        dadosResposta.expand((dados) => dados).toList(),
      );

      return resposta;
    } catch (erro) {
      // Anexa em qual etapa a falha aconteceu para que
      // a mensagem de erro possa apontar a causa real
      // (conexão recusada? envio? espera da resposta?).
      throw AnaliseException(etapa, erro);
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
    } on AnaliseException catch (erro) {
      if (mounted) {
        setState(() {
          _resultado = _mensagemErroAmigavel(erro);
        });
      }
    } catch (erro) {
      // Erros fora do envio (câmera, leitura da foto
      // etc.) também precisam aparecer na tela.
      if (mounted) {
        setState(() {
          _resultado = 'Erro inesperado:\n$erro';
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

  // Traduz erros comuns para mensagens mais úteis,
  // indicando a etapa em que a falha aconteceu.
  String _mensagemErroAmigavel(AnaliseException erro) {
    final texto = erro.erro.toString().toLowerCase();

    if (erro.etapa == ConnectStage.conexao) {
      // O tempo de conexão esgotou: os pacotes
      // provavelmente estão sendo descartados
      // pela rede (nem chegaram ao servidor).
      if (texto.contains('timed out') ||
          texto.contains('timeout')) {
        return 'Não foi possível conectar ao servidor '
            '(tempo esgotado na conexão).\n\n'
            'Possíveis causas:\n'
            '• IP errado: ao trocar de rede o IP do notebook\n'
            '  MUDA (hotspot: 192.168.43.x | cabo USB:\n'
            '  192.168.42.x). Confira o IP atual na janela\n'
            '  do server.py ("IPs deste computador")\n'
            '• Firewall do notebook bloqueando a porta 8080\n'
            '  (no hotspot/cabo o Windows costuma tratar a\n'
            '  rede como "Pública" — a regra precisa valer\n'
            '  para qualquer perfil: profile=any)\n'
            '• Celular usando dados móveis em vez da rede\n'
            '• A rede bloqueia a comunicação entre aparelhos\n'
            '  (isolamento de clientes, comum em redes de\n'
            '  universidade, ex.: UFPI)\n\n'
            'Dica: toque em Testar conexão para validar o\n'
            'IP e a porta antes de analisar uma foto.';
      }

      // Ninguém escutando na porta informada.
      if (texto.contains('refused')) {
        return 'Conexão recusada pelo servidor.\n\n'
            'Verifique se o server.py está rodando e\n'
            'exibindo "Aguardando imagem..." (porta 8080).';
      }

      // Sem rota até o endereço informado.
      if (texto.contains('unreachable') ||
          texto.contains('no route to host')) {
        return 'Rede inacessível.\n\n'
            'Verifique se o celular e o notebook estão\n'
            'na mesma rede Wi-Fi (e sem dados móveis).';
      }

      return 'Falha ao conectar ao servidor:\n$erro';
    }

    if (erro.etapa == ConnectStage.envio) {
      return 'A conexão abriu, mas falhou ao enviar a foto:\n'
          '$erro';
    }

    // Etapa da resposta.
    if (texto.contains('timeout')) {
      return 'A foto foi enviada, mas o servidor não '
          'respondeu em 60 s.\n\n'
          'A detecção (YOLO) pode estar demorando muito.\n'
          'Confira a janela do servidor no notebook.';
    }

    return 'Falha ao receber a resposta do servidor:\n'
        '$erro';
  }

  // Envia a sonda de teste de conexão (4 bytes com tamanho
  // 0), que o servidor responde "OK" na hora, sem
  // processar imagem — igual ao cliente_teste.py --testar.
  Future<void> _testarConexao() async {
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

    setState(() {
      _testandoConexao = true;
      _resultado = 'Testando conexão com $ip:$porta...';
    });

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
        0,
        Endian.big,
      );

      socket.add(cabecalho.buffer.asUint8List());

      await socket.flush();

      final dadosResposta = await socket
          .toList()
          .timeout(const Duration(seconds: 10));

      final resposta = utf8.decode(
        dadosResposta.expand((dados) => dados).toList(),
      );

      if (mounted) {
        setState(() {
          _resultado = resposta.trim() == 'OK'
              ? 'Conexão OK! O servidor em $ip:$porta\n'
                  'respondeu. Agora toque em Tirar e Analisar.'
              : 'Servidor respondeu: $resposta';
        });
      }
    } catch (erro) {
      if (mounted) {
        setState(() {
          _resultado = _mensagemErroAmigavel(
            AnaliseException(ConnectStage.conexao, erro),
          );
        });
      }
    } finally {
      socket?.destroy();

      // Libera os botões para a próxima tentativa.
      if (mounted) {
        setState(() {
          _testandoConexao = false;
        });
      }
    }
  }

  String _formatarResultado(String resposta) {
    final texto = resposta.trim();

    if (texto.isEmpty) {
      return 'Erro: o servidor não retornou resposta.';
    }

    if (texto == 'Nada Detectado') {
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

  // Procura o servidor na rede local via broadcast UDP
  // (mesmo mecanismo do cliente_teste.py --descobrir).
  Future<void> _procurarServidor() async {
    setState(() {
      _procurando = true;
      _resultado = 'Procurando servidor na rede...';
    });

    RawDatagramSocket? udp;

    try {
      udp = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );

      udp.broadcastEnabled = true;

      Datagram? pacote;

      final pergunta = utf8.encode('DETECTOR_DISCOVERY');

      final fim = DateTime.now().add(
        const Duration(seconds: 3),
      );

      // Repete o ping a cada 300 ms: um único pacote UDP
      // pode se perder, o que faria a busca falhar
      // sem motivo.
      while (DateTime.now().isBefore(fim)) {

        udp.send(
          pergunta,
          InternetAddress('255.255.255.255'),
          8081,
        );

        final limite = DateTime.now().add(
          const Duration(milliseconds: 300),
        );

        while (DateTime.now().isBefore(limite)) {

          pacote = udp.receive();

          if (pacote != null) break;

          await Future<void>.delayed(
            const Duration(milliseconds: 50),
          );
        }

        if (pacote != null) break;
      }

      if (!mounted) return;

      if (pacote == null) {
        setState(() {
          _resultado = 'Nenhum servidor encontrado.\n\n'
              '1. Confira se o server.py está rodando\n'
              '2. Celular e notebook na MESMA rede\n'
              '3. Libere no firewall as portas TCP 8080\n'
              '   e UDP 8081 (profile=any)\n'
              '4. Se o notebook trocou de rede, o IP muda:\n'
              '   veja o IP na janela do server.py e\n'
              '   digite manualmente\n'
              '5. Ainda sem sucesso? Refaça o hotspot:\n'
              '   ative o ponto de acesso no celular,\n'
              '   conecte o notebook a ele e tente de novo';
        });

        return;
      }

      final texto = utf8.decode(pacote.data);

      if (!texto.startsWith('DETECTOR_SERVER|')) {
        setState(() {
          _resultado = 'Resposta inválida de ${pacote!.address.address}.';
        });

        return;
      }

      final ip = pacote.address.address;

      final porta = int.parse(
        texto.split('|')[1],
      );

      setState(() {
        _ipController.text = ip;
        _portaController.text = '$porta';
        _resultado = 'Servidor encontrado em $ip:$porta!\n'
            'Agora toque em Tirar e Analisar.';
      });
    } catch (erro) {
      if (mounted) {
        setState(() {
          _resultado = 'Erro ao procurar o servidor:\n$erro';
        });
      }
    } finally {
      udp?.close();

      // Sem isso, os botões ficam travados para sempre
      // após a primeira busca.
      if (mounted) {
        setState(() {
          _procurando = false;
        });
      }
    }
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
              // datetime exibe números com ponto,
              // facilitando digitar o IP
              keyboardType: TextInputType.datetime,
              autocorrect: false,
              enableSuggestions: false,
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

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _ocupado
                          ? null
                          : _tirarEAnalisar,
                      icon: const Icon(Icons.camera_alt),
                      label: Text(
                        _analisando
                            ? 'Analisando...'
                            : 'Tirar e Analisar',
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed:
                          _ocupado
                              ? null
                              : _procurarServidor,
                      icon: const Icon(Icons.search),
                      label: Text(
                        _procurando
                            ? 'Procurando...'
                            : 'Procurar servidor',
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Sonda rápida: confirma se o app consegue
            // falar com o servidor antes de gastar
            // uma foto.
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _ocupado ? null : _testarConexao,
                icon: const Icon(Icons.wifi),
                label: Text(
                  _testandoConexao
                      ? 'Testando...'
                      : 'Testar conexão',
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Atalho para o cenário mais comum de falha:
            // redes de universidade bloqueiam a conexão
            // entre aparelhos. O hotspot do celular cria
            // uma rede que só depende de você.
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: null,
                icon: const Icon(Icons.wifi_tethering, size: 18),
                label: const Text(
                  'Sem conexão? Ative o hotspot do celular, '
                  'conecte o notebook a ele e toque em '
                  'Procurar servidor.',
                  textAlign: TextAlign.center,
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