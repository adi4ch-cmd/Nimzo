"""ABI policy regression tests: locked Pigeon and JNI plugin generations."""
import unittest
from verify_shared_preferences_android_abi import required_signatures, validate_signatures

class AbiPolicyTests(unittest.TestCase):
    def test_locked_pigeon_requires_both_concrete_plugin_entrypoints(self):
        expected=required_signatures('2.4.28')
        self.assertEqual(len(expected),2)
        self.assertTrue(all('Registrar' not in cls for cls,_,_ in expected))
        validate_signatures('2.4.28',expected)
        with self.assertRaises(ValueError):
            validate_signatures('2.4.28',expected[:1])

    def test_jni_plugin_requires_kotlin_continuation(self):
        expected=required_signatures('2.5.1')
        self.assertIn('Lkotlin/coroutines/Continuation;',expected[0][2])
        validate_signatures('2.5.1',expected)
        wrong=[(expected[0][0],expected[0][1],expected[0][2][:-1])]
        with self.assertRaises(ValueError):
            validate_signatures('2.5.1',wrong)

    def test_version_and_compiled_generation_must_match(self):
        with self.assertRaises(ValueError):
            validate_signatures('2.4.28',required_signatures('2.5.1'))
        with self.assertRaises(ValueError):
            validate_signatures('2.5.1',required_signatures('2.4.28'))
        with self.assertRaises(ValueError):
            required_signatures('99.0.0')

if __name__=='__main__':
    unittest.main()
