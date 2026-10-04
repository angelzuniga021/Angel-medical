package com.drangelzuniga.angel_medical_mobile;

import org.junit.Test;
import static org.junit.Assert.*;
import java.security.*;
import java.math.BigInteger;
import java.util.*;
import java.nio.file.*;
import javax.security.auth.x500.X500Principal;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder;
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder;
import org.bouncycastle.openssl.*;
import org.bouncycastle.openssl.jcajce.*;

public class LocalSignerTest {
  private static final BouncyCastleProvider BC = new BouncyCastleProvider();
  private static class Fixture {
    byte[] cert, key;
    Fixture(long expiry) throws Exception {
      KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA"); generator.initialize(2048);
      KeyPair pair = generator.generateKeyPair();
      Date before = new Date(System.currentTimeMillis()-86400000L), after = new Date(System.currentTimeMillis()+expiry);
      X500Principal subject = new X500Principal("CN=MEDICO FICTICIO,OID.2.5.4.45=AAAA900101AB1");
      cert = new JcaX509v3CertificateBuilder(subject, BigInteger.valueOf(99), before, after, subject, pair.getPublic()).build(new JcaContentSignerBuilder("SHA256withRSA").setProvider(BC).build(pair.getPrivate())).getEncoded();
      key = new JcaPKCS8Generator(pair.getPrivate(), new JceOpenSSLPKCS8EncryptorBuilder(PKCS8Generator.AES_256_CBC).setProvider(BC).setRandom(new SecureRandom()).setPassword("fixture-only".toCharArray()).build()).generate().getContent();
    }
  }
  @Test public void signVerifyAndTamper() throws Exception {
    Fixture f = new Fixture(86400000L); byte[] content = "Fictitious clinical note fixture only".getBytes("UTF-8");
    Map<String,Object> signed = LocalSigner.sign(content, f.cert, f.key.clone(), "fixture-only".toCharArray());
    assertEquals(true, signed.get("valid")); assertEquals(false, signed.get("trustVerified"));
    byte[] cms = (byte[])signed.get("cms"); assertEquals(true, LocalSigner.verify(content, cms).get("valid"));
    try { assertFalse(Boolean.TRUE.equals(LocalSigner.verify("tampered".getBytes("UTF-8"), cms).get("valid"))); } catch (Exception expected) { }
    Path dir = Paths.get(System.getenv("ANGEL_FIXTURE_DIR") != null ? System.getenv("ANGEL_FIXTURE_DIR") : "build/signature-fixture"); Files.createDirectories(dir);
    Files.write(dir.resolve("document.txt"), content); Files.write(dir.resolve("document.p7s"), cms);
  }
  @Test public void rejectsWrongPasswordAndMismatchAndExpired() throws Exception {
    Fixture f = new Fixture(86400000L); Fixture other = new Fixture(86400000L);
    for (int i=0;i<3;i++) {
      Fixture selected = i == 2 ? new Fixture(-1000L) : f;
      byte[] key = selected.key.clone(); char[] password = (i == 0 ? "wrong" : "fixture-only").toCharArray();
      try { LocalSigner.sign(new byte[]{1,2,3}, i == 1 ? other.cert : selected.cert, key, password); fail("Invalid signing inputs accepted"); }
      catch (Exception expected) { }
      for (byte b : key) assertEquals(0, b); for (char c : password) assertEquals(0, c);
    }
  }
}
