package com.drangelzuniga.angel_medical_mobile;

import java.io.ByteArrayInputStream;
import java.security.PrivateKey;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;
import java.util.*;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.bouncycastle.pkcs.PKCS8EncryptedPrivateKeyInfo;
import org.bouncycastle.openssl.jcajce.JceOpenSSLPKCS8DecryptorProviderBuilder;
import org.bouncycastle.openssl.jcajce.JcaPEMKeyConverter;
import org.bouncycastle.cert.jcajce.JcaCertStore;
import org.bouncycastle.cert.X509CertificateHolder;
import org.bouncycastle.cms.*;
import org.bouncycastle.cms.jcajce.*;
import org.bouncycastle.operator.jcajce.*;

/** Offline CMS signature: mathematical integrity only, no SAT trust assertion. */
public final class LocalSigner {
  public static final class Failure extends Exception {
    public final String code;
    Failure(String code) { super(code); this.code = code; }
  }
  private static final BouncyCastleProvider PROVIDER = new BouncyCastleProvider();
  private static void bounded(byte[] data, int max) {
    if (data == null || data.length == 0 || data.length > max) throw new IllegalArgumentException("Tamaño de archivo no permitido");
  }
  public static Map<String,Object> sign(byte[] data, byte[] certificate, byte[] encryptedKey, char[] password) throws Exception {
    try {
      bounded(data, 8*1024*1024); bounded(certificate, 128*1024); bounded(encryptedKey, 128*1024);
      if (password == null || password.length == 0 || password.length > 1024) throw new IllegalArgumentException("Contraseña requerida");
      X509Certificate cert;
      try { cert = (X509Certificate) CertificateFactory.getInstance("X.509").generateCertificate(new ByteArrayInputStream(certificate)); }
      catch (Exception e) { throw new Failure("CERT_INVALID"); }
      try { cert.checkValidity(); }
      catch (java.security.cert.CertificateExpiredException e) { throw new Failure("CERT_EXPIRED"); }
      catch (java.security.cert.CertificateNotYetValidException e) { throw new Failure("CERT_NOT_YET_VALID"); }
      boolean[] usage = cert.getKeyUsage();
      if (usage != null && !usage[0] && !(usage.length > 1 && usage[1])) throw new IllegalArgumentException("Certificado sin uso de firma");
      // Accept encrypted DER PKCS#8 only. Never fall back to an unencrypted key.
      PKCS8EncryptedPrivateKeyInfo encoded;
      try { encoded = new PKCS8EncryptedPrivateKeyInfo(encryptedKey); }
      catch (Exception e) { throw new Failure("KEY_READ_FAILED"); }
      PrivateKey key;
      try { key = new JcaPEMKeyConverter().setProvider(PROVIDER).getPrivateKey(encoded.decryptPrivateKeyInfo(new JceOpenSSLPKCS8DecryptorProviderBuilder().setProvider(PROVIDER).build(password))); }
      catch (Exception e) { throw new Failure("KEY_DECRYPT_FAILED"); }
      if (!(key instanceof RSAPrivateKey) || ((RSAPrivateKey)key).getModulus().bitLength() < 2048) throw new IllegalArgumentException("Se requiere clave RSA de al menos 2048 bits");
      if (!(cert.getPublicKey() instanceof RSAPublicKey) || !((RSAPrivateKey)key).getModulus().equals(((RSAPublicKey)cert.getPublicKey()).getModulus())) throw new Failure("CERT_KEY_MISMATCH");
      CMSSignedDataGenerator generator = new CMSSignedDataGenerator();
      generator.addSignerInfoGenerator(new JcaSignerInfoGeneratorBuilder(new JcaDigestCalculatorProviderBuilder().setProvider(PROVIDER).build()).build(new JcaContentSignerBuilder("SHA256withRSA").setProvider(PROVIDER).build(key), cert));
      generator.addCertificates(new JcaCertStore(Collections.singletonList(cert)));
      byte[] cms = generator.generate(new CMSProcessableByteArray(data), false).toASN1Structure().getEncoded(org.bouncycastle.asn1.ASN1Encoding.DER);
      // A mismatched certificate/key must not be saved as a successful signature.
      Map<String,Object> result;
      try { result = verify(data, cms); }
      catch (Exception e) { throw new Failure("SIGNATURE_FAILED"); }
      if (!Boolean.TRUE.equals(result.get("valid"))) throw new Failure("CERT_KEY_MISMATCH");
      result.put("cms", cms);
      return result;
    } finally {
      if (password != null) Arrays.fill(password, '\0');
      if (encryptedKey != null) Arrays.fill(encryptedKey, (byte)0);
    }
  }
  @SuppressWarnings({"unchecked", "rawtypes"})
  public static Map<String,Object> verify(byte[] data, byte[] cms) throws Exception {
    bounded(data, 8*1024*1024); bounded(cms, 1024*1024);
    CMSSignedData signed = new CMSSignedData(new CMSProcessableByteArray(data), cms);
    if (!signed.isDetachedSignature() || signed.getSignerInfos().size() != 1) throw new IllegalArgumentException("Formato de firma no soportado");
    SignerInformation signer = signed.getSignerInfos().getSigners().iterator().next();
    if (!"2.16.840.1.101.3.4.2.1".equals(signer.getDigestAlgOID())) throw new IllegalArgumentException("Se requiere SHA-256");
    Collection matches = signed.getCertificates().getMatches(signer.getSID());
    if (matches.size() != 1) throw new IllegalArgumentException("Certificado del firmante ambiguo o ausente");
    X509CertificateHolder holder = (X509CertificateHolder) matches.iterator().next();
    boolean valid = signer.verify(new JcaSimpleSignerInfoVerifierBuilder().setProvider(PROVIDER).build(holder));
    Map<String,Object> result = new HashMap<>();
    result.put("valid", valid); result.put("subject", holder.getSubject().toString());
    result.put("certificate", holder.getEncoded());
    result.put("serial", holder.getSerialNumber().toString(16));
    result.put("certificateInDate", holder.isValidOn(new Date()));
    result.put("trustVerified", false); result.put("revocationVerified", false);
    return result;
  }
}
