void setup() {
  // Cria a comunicação serial para exibir os valores no monitor serial
  Serial.begin(115200); // baud = taxa de transferência de bits: bits por segundo
  Serial.println("\n\n\n           Voltímetro 6 canais");
  Serial.println("A0(V)   A1(V)   A2(V)   A3(V)   A4(V)   A5(V)");
}

void loop() {
  float tensao[6];
  int chMax=5;
  int chN;  
  // Mede o valor de 0 a 1023 e converte para tensão
  //           o (float) faz um coerção, pois o comando analogRead retorna um numero inteiro e a tensão é um float
  for (chN=0;chN<=chMax;chN++) {
   tensao[chN] = (float)analogRead(chN)*5/1023;      
   Serial.print(tensao[chN],4); // com 4 digitos
    Serial.print("\t");
   }
    Serial.print("\n");
  // Cria um pequeno atraso entre cada medição
  delay(1000);
}
