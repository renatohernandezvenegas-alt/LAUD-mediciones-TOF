%% ===================================================================== %%
%     ADQUISICIÓN DE DATOS DESDE OSCILOSCOPIO Y EXCITACIÓN CON AGILENT
%                Válido para: RIGOL DS1204B y Agilent 33220A
%          Laboratorio de Acústica musical Lutheria Postdigital LAÚD
%% ===================================================================== %%

clc; clear; close all;
%% ========================= AJUSTAR ESTOS DATOS ========================= %%
disp ('Ejecutar en Command Window visadevlist y reemplazan GEN_ID y GEN_OSC con los valores correctos');
GEN_ID = "USB0::0x0957::0x0407::MY44022852::0::INSTR";   % Generador Agilent 33220A
OSC_ID = "USB0::0x1AB1::0x0588::DS1ZA203700099::0::INSTR"; % Osciloscopio Rigol DS1204B

%% ======================= CONECTAR A LOS EQUIPOS ========================= %%
try
    GEN = visadev(GEN_ID);
    disp("Generador conectado correctamente.");
catch
    error("MATLAB NO pudo conectar el generador. Revisa 'visadevlist'.");
end

try
    OSC = visadev(OSC_ID);
    disp("Osciloscopio conectado correctamente.");
catch
    error("MATLAB NO pudo conectar el osciloscopio. Revisa 'visadevlist'.");
end


%% ===================================================================== %%
%                CONFIGURAR GENERADOR AGILENT 33220A
%% ===================================================================== %%

% Parámetros del burst ultrasónico
f_res      = 2.25e6;     % Frecuencia del transductor (2.25 MHz)
n_ciclos   = 5;          % Ciclos del burst
fs         = 20e6;       % Frec. muestreo ARB (máx. del Agilent)
f_rep      = 1000;       % Frecuencia entre pulsos (1 kHz)

% Tiempo total entre pulsos
T_total = 1 / f_rep;
N_total = round(fs * T_total);
t = (0:N_total-1) / fs;

% Duración activa del burst
N_act = round((n_ciclos / f_res) * fs);

% Construir onda: 5 ciclos + silencio
onda = [sin(2*pi*f_res*t(1:N_act)), zeros(1, N_total-N_act)];
onda = onda / max(abs(onda));               % Normalizar -1 a +1
onda_dac = uint16((onda+1)*(16383/2));      % Convertir a 14 bits

% Cargar forma arbitraria
writeline(GEN, "OUTP OFF");
writeline(GEN, "DATA:VOL:CLE");
binblockwrite(GEN, onda_dac, "uint16", "DATA:DAC ARB1,");
writeline(GEN, "");   % Terminar comando SCPI

% Seleccionar la forma y parámetros
writeline(GEN, "FUNC:USER ARB1");
writeline(GEN, "FUNC USER");
writeline(GEN, sprintf("FREQ %f", f_rep));
writeline(GEN, "VOLT 1");          % Amplitud de salida
writeline(GEN, "VOLT:OFFS 0");
writeline(GEN, "OUTP ON");

disp("Señal ultrasónica enviada al generador.");


%% ===================================================================== %%
%                      CONFIGURAR OSCILOSCOPIO RIGOL
%% ===================================================================== %%

writeline(OSC, ":STOP");
pause(0.1);

writeline(OSC, ":CHAN1:SCAL 1");
writeline(OSC, ":CHAN2:SCAL 1");
writeline(OSC, ":TIM:SCAL 2e-7");       % 200 ns/div → ideal para 2.25 MHz
writeline(OSC, ":ACQ:AVER 16");        % Promediado moderado
writeline(OSC, ":RUN");

pause(1);


%% ===================================================================== %%
%                   FUNCIÓN PARA LEER UN CANAL DEL OSCILOSCOPIO
%% ===================================================================== %%
function [t, v] = obtenerCanal(OSC, canal)
    writeline(OSC, sprintf(":WAV:SOUR CHAN%d", canal));
    writeline(OSC, ":WAV:MODE NORM");
    writeline(OSC, ":WAV:FORM BYTE");
    writeline(OSC, ":WAV:POIN 6000");

    yinc = str2double(query(OSC, sprintf(":WAV:YINC? CHAN%d",canal)));
    yref = str2double(query(OSC, sprintf(":WAV:YREF? CHAN%d",canal)));
    yor  = str2double(query(OSC, sprintf(":WAV:YOR? CHAN%d", canal)));

    xinc = str2double(query(OSC, sprintf(":WAV:XINC? CHAN%d",canal)));
    xorg = str2double(query(OSC, sprintf(":WAV:XOR? CHAN%d", canal)));

    writeline(OSC, ":WAV:DATA?");
    raw = binblockread(OSC, "uint8");
    readline(OSC);   % limpia el buffer SCPI

    v = (double(raw) - yref - yor) * yinc;
    t = xorg + (0:length(v)-1)*xinc;
end


%% ===================================================================== %%
%                             ADQUISICIÓN REAL
%% ===================================================================== %%

[t1, v1] = obtenerCanal(OSC, 1);
[t2, v2] = obtenerCanal(OSC, 2);

figure;
plot(t1, v1, 'b'); hold on;
plot(t2, v2, 'r');
grid on;
xlabel("Tiempo [s]");
ylabel("Voltaje [V]");
title("Señales adquiridas desde Rigol");
legend("CH1 - Emisor", "CH2 - Receptor");

disp("Datos adquiridos correctamente.");


