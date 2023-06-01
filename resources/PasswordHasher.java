import java.util.Base64;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;

public class PasswordHasher {
    private static final int KEY_LEN = 512;
    private static final int HASH_ITERATIONS = 100_000;
    private static final int PARAM_SALT_INDEX = 0;
    private static final int PARAM_PASSWORD_INDEX = 1;

    public static void main(String[] args) {
        var saltStr = args[PARAM_SALT_INDEX];
        var password = args[PARAM_PASSWORD_INDEX];
        byte[] salt = Base64.getDecoder().decode(saltStr);
        var hashedPassword = hash(salt, password, HASH_ITERATIONS);
        hashedPassword = String.format("%d$%s", HASH_ITERATIONS, hashedPassword);
        System.out.print(hashedPassword);
    }

    private static String hash(byte[] salt, String password, int iterations) {
        try {
            SecretKeyFactory skf = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA512");
            PBEKeySpec spec = new PBEKeySpec(password.toCharArray(), salt, iterations, KEY_LEN);
            byte[] hash = skf.generateSecret(spec).getEncoded();
            return Base64.getEncoder().encodeToString(hash);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}