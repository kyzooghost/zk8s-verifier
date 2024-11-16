// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../contracts/verifiers/V4QuoteVerifier.sol";
import "../contracts/PCCSRouter.sol";
import {RiscZeroGroth16Verifier} from "risc0/groth16/RiscZeroGroth16Verifier.sol";
import "../contracts/ZK8sVerifier.sol";

import {
    EnclaveIdentityJsonObj,
    EnclaveIdentityHelper,
    IdentityObj
} from "@automata-network/on-chain-pccs/helpers/EnclaveIdentityHelper.sol";
import {TcbInfoJsonObj, FmspcTcbHelper} from "@automata-network/on-chain-pccs/helpers/FmspcTcbHelper.sol";
import {PCKHelper} from "@automata-network/on-chain-pccs/helpers/PCKHelper.sol";
import {X509CRLHelper} from "@automata-network/on-chain-pccs/helpers/X509CRLHelper.sol";

import {AutomataFmspcTcbDao} from "@automata-network/on-chain-pccs/automata_pccs/AutomataFmspcTcbDao.sol";
import {AutomataEnclaveIdentityDao} from "@automata-network/on-chain-pccs/automata_pccs/AutomataEnclaveIdentityDao.sol";
import {AutomataPcsDao} from "@automata-network/on-chain-pccs/automata_pccs/AutomataPcsDao.sol";
import {AutomataPckDao} from "@automata-network/on-chain-pccs/automata_pccs/AutomataPckDao.sol";
import {AutomataDaoStorage} from "@automata-network/on-chain-pccs/automata_pccs/shared/AutomataDaoStorage.sol";

contract DeploySystem is Script {
    uint256 deployerKey = uint256(vm.envBytes32("PRIVATE_KEY"));
    bytes32 riscZeroImageId = vm.envBytes32("DCAP_IMAGE_ID");

    bytes32 public constant CONTROL_ROOT = hex"a516a057c9fbf5629106300934d48e0e775d4230e41e503347cad96fcbde7e2e";
    // NOTE: This has opposite byte order to the value in the risc0 repository.
    bytes32 public constant BN254_CONTROL_ID = hex"0eb6febcf06c5df079111be116f79bd8c7e85dc9448776ef9a59aaf2624ab551";

    RiscZeroGroth16Verifier riscZeroVerifier;

    function run() public {
        vm.startBroadcast(deployerKey);

        _deployP256();
        EnclaveIdentityHelper enclaveIdHelper = new EnclaveIdentityHelper();
        FmspcTcbHelper tcbHelper = new FmspcTcbHelper();
        PCKHelper x509 = new PCKHelper();
        X509CRLHelper x509Crl = new X509CRLHelper();

        AutomataDaoStorage pccsStorage = new AutomataDaoStorage();
        AutomataPcsDao pcsDao = new AutomataPcsDao(address(pccsStorage), address(x509), address(x509Crl));
        AutomataPckDao pckDao = new AutomataPckDao(address(pccsStorage), address(pcsDao), address(x509), address(x509Crl));
        AutomataEnclaveIdentityDao enclaveIdDao = new AutomataEnclaveIdentityDao(
            address(pccsStorage), address(pcsDao), address(enclaveIdHelper), address(x509)
        );
        AutomataFmspcTcbDao fmspcTcbDao = new AutomataFmspcTcbDao(address(pccsStorage), address(pcsDao), address(tcbHelper), address(x509));
        pccsStorage.updateDao(address(pcsDao), address(pckDao), address(enclaveIdDao), address(fmspcTcbDao));


        PCCSRouter router =
            new PCCSRouter(
                address(enclaveIdDao), 
                address(fmspcTcbDao), 
                address(pcsDao), 
                address(pckDao), 
                address(x509), 
                address(x509Crl)
            );
        console2.log("Deployed PCCSRouter to", address(router));

        pcsDaoUpserts(pcsDao);

        V4QuoteVerifier verifier = new V4QuoteVerifier(address(router));
        console.log("V4QuoteVerifier deployed at ", address(verifier));

        riscZeroVerifier = new RiscZeroGroth16Verifier(CONTROL_ROOT, BN254_CONTROL_ID);
        console2.log("Deployed RiscZeroGroth16Verifier to", address(riscZeroVerifier));

        ZK8SVerifier zk8sVerifier = new ZK8SVerifier(address(riscZeroVerifier), riscZeroImageId);
        console.log("ZK8sVerifier deployed at: ", address(zk8sVerifier));
        zk8sVerifier.setQuoteVerifier(address(verifier));

        vm.stopBroadcast();
    }

    function pcsDaoUpserts(AutomataPcsDao pcsDao) internal {

        bytes memory tcbDer = hex"3082028b30820232a00302010202147e3882d5fb55294a40498e458403e91491bdf455300a06082a8648ce3d0403023068311a301806035504030c11496e74656c2053475820526f6f74204341311a3018060355040a0c11496e74656c20436f72706f726174696f6e3114301206035504070c0b53616e746120436c617261310b300906035504080c024341310b3009060355040613025553301e170d3138303532313130353031305a170d3235303532313130353031305a306c311e301c06035504030c15496e74656c2053475820544342205369676e696e67311a3018060355040a0c11496e74656c20436f72706f726174696f6e3114301206035504070c0b53616e746120436c617261310b300906035504080c024341310b30090603550406130255533059301306072a8648ce3d020106082a8648ce3d0301070342000443451bcc73c9d5917caf766e61af3fe98087dd4f13257b261e851897799dd13d6811fb47713803bb9bae587fccddc2e31be9a28b86962acc6daf96da58eeca96a381b53081b2301f0603551d2304183016801422650cd65a9d3489f383b49552bf501b392706ac30520603551d1f044b30493047a045a043864168747470733a2f2f6365727469666963617465732e7472757374656473657276696365732e696e74656c2e636f6d2f496e74656c534758526f6f7443412e646572301d0603551d0e041604147e3882d5fb55294a40498e458403e91491bdf455300e0603551d0f0101ff0404030206c0300c0603551d130101ff04023000300a06082a8648ce3d040302034700304402201f42f3038037f226c43b46002576e3a29caa36a064e47493272dc81aec1862550220237ed6eb346b0653c607db5d5d46260da0f3eed7d669ff37bc26686e8c1d2807";

        bytes memory rootCaDer =
        hex"3082028f30820234a003020102021422650cd65a9d3489f383b49552bf501b392706ac300a06082a8648ce3d0403023068311a301806035504030c11496e74656c2053475820526f6f74204341311a3018060355040a0c11496e74656c20436f72706f726174696f6e3114301206035504070c0b53616e746120436c617261310b300906035504080c024341310b3009060355040613025553301e170d3138303532313130343531305a170d3439313233313233353935395a3068311a301806035504030c11496e74656c2053475820526f6f74204341311a3018060355040a0c11496e74656c20436f72706f726174696f6e3114301206035504070c0b53616e746120436c617261310b300906035504080c024341310b30090603550406130255533059301306072a8648ce3d020106082a8648ce3d030107034200040ba9c4c0c0c86193a3fe23d6b02cda10a8bbd4e88e48b4458561a36e705525f567918e2edc88e40d860bd0cc4ee26aacc988e505a953558c453f6b0904ae7394a381bb3081b8301f0603551d2304183016801422650cd65a9d3489f383b49552bf501b392706ac30520603551d1f044b30493047a045a043864168747470733a2f2f6365727469666963617465732e7472757374656473657276696365732e696e74656c2e636f6d2f496e74656c534758526f6f7443412e646572301d0603551d0e0416041422650cd65a9d3489f383b49552bf501b392706ac300e0603551d0f0101ff04040302010630120603551d130101ff040830060101ff020101300a06082a8648ce3d0403020349003046022100e5bfe50911f92f428920dc368a302ee3d12ec5867ff622ec6497f78060c13c20022100e09d25ac7a0cb3e5e8e68fec5fa3bd416c47440bd950639d450edcbea4576aa2";
    bytes memory platformDer =
        hex"308202963082023da003020102021500956f5dcdbd1be1e94049c9d4f433ce01570bde54300a06082a8648ce3d0403023068311a301806035504030c11496e74656c2053475820526f6f74204341311a3018060355040a0c11496e74656c20436f72706f726174696f6e3114301206035504070c0b53616e746120436c617261310b300906035504080c024341310b3009060355040613025553301e170d3138303532313130353031305a170d3333303532313130353031305a30703122302006035504030c19496e74656c205347582050434b20506c6174666f726d204341311a3018060355040a0c11496e74656c20436f72706f726174696f6e3114301206035504070c0b53616e746120436c617261310b300906035504080c024341310b30090603550406130255533059301306072a8648ce3d020106082a8648ce3d0301070342000435207feeddb595748ed82bb3a71c3be1e241ef61320c6816e6b5c2b71dad5532eaea12a4eb3f948916429ea47ba6c3af82a15e4b19664e52657939a2d96633dea381bb3081b8301f0603551d2304183016801422650cd65a9d3489f383b49552bf501b392706ac30520603551d1f044b30493047a045a043864168747470733a2f2f6365727469666963617465732e7472757374656473657276696365732e696e74656c2e636f6d2f496e74656c534758526f6f7443412e646572301d0603551d0e04160414956f5dcdbd1be1e94049c9d4f433ce01570bde54300e0603551d0f0101ff04040302010630120603551d130101ff040830060101ff020100300a06082a8648ce3d040302034700304402205ec5648b4c3e8ba558196dd417fdb6b9a5ded182438f551e9c0f938c3d5a8b970220261bd520260f9c647d3569be8e14a32892631ac358b994478088f4d2b27cf37e";

    bytes memory platformCrlDer =
        hex"30820a6230820a08020101300a06082a8648ce3d04030230703122302006035504030c19496e74656c205347582050434b20506c6174666f726d204341311a3018060355040a0c11496e74656c20436f72706f726174696f6e3114301206035504070c0b53616e746120436c617261310b300906035504080c024341310b3009060355040613025553170d3234303632373133313733385a170d3234303732373133313733385a30820934303302146fc34e5023e728923435d61aa4b83c618166ad35170d3234303632373133313733385a300c300a0603551d1504030a01013034021500efae6e9715fca13b87e333e8261ed6d990a926ad170d3234303632373133313733385a300c300a0603551d1504030a01013034021500fd608648629cba73078b4d492f4b3ea741ad08cd170d3234303632373133313733385a300c300a0603551d1504030a010130340215008af924184e1d5afddd73c3d63a12f5e8b5737e56170d3234303632373133313733385a300c300a0603551d1504030a01013034021500b1257978cfa9ccdd0759abf8c5ca72fae3a78a9b170d3234303632373133313733385a300c300a0603551d1504030a01013033021474fea614a972be0e2843f2059835811ed872f9b3170d3234303632373133313733385a300c300a0603551d1504030a01013034021500f9c4ef56b3ab48d577e108baedf4bf88014214b9170d3234303632373133313733385a300c300a0603551d1504030a010130330214071de0778f9e5fc4f2878f30d6b07c9a30e6b30b170d3234303632373133313733385a300c300a0603551d1504030a01013034021500cde2424f972cea94ff239937f4d80c25029dd60b170d3234303632373133313733385a300c300a0603551d1504030a0101303302146c3319e5109b64507d3cf1132ce00349ef527319170d3234303632373133313733385a300c300a0603551d1504030a01013034021500df08d756b66a7497f43b5bb58ada04d3f4f7a937170d3234303632373133313733385a300c300a0603551d1504030a01013033021428af485b6cf67e409a39d5cb5aee4598f7a8fa7b170d3234303632373133313733385a300c300a0603551d1504030a01013034021500fb8b2daec092cada8aa9bc4ff2f1c20d0346668c170d3234303632373133313733385a300c300a0603551d1504030a01013034021500cd4850ac52bdcc69a6a6f058c8bc57bbd0b5f864170d3234303632373133313733385a300c300a0603551d1504030a01013034021500994dd3666f5275fb805f95dd02bd50cb2679d8ad170d3234303632373133313733385a300c300a0603551d1504030a0101303302140702136900252274d9035eedf5457462fad0ef4c170d3234303632373133313733385a300c300a0603551d1504030a01013033021461f2bf73e39b4e04aa27d801bd73d24319b5bf80170d3234303632373133313733385a300c300a0603551d1504030a0101303302143992be851b96902eff38959e6c2eff1b0651a4b5170d3234303632373133313733385a300c300a0603551d1504030a010130330214639f139a5040fdcff191e8a4fb1bf086ed603971170d3234303632373133313733385a300c300a0603551d1504030a01013034021500959d533f9249dc1e513544cdc830bf19b7f1f301170d3234303632373133313733385a300c300a0603551d1504030a0101303302140fda43a00b68ea79b7c2deaeac0b498bdfb2af90170d3234303632373133313733385a300c300a0603551d1504030a010130340215009d67753b81e47090aea763fbec4c4549bcdb9933170d3234303632373133313733385a300c300a0603551d1504030a01013033021434bfbb7a1d9c568147e118b614f7b76ed3ef68df170d3234303632373133313733385a300c300a0603551d1504030a0101303402150085d3c9381b77a7e04d119c9e5ad6749ff3ffab87170d3234303632373133313733385a300c300a0603551d1504030a0101303402150093887ca4411e7a923bd1fed2819b2949f201b5b4170d3234303632373133313733385a300c300a0603551d1504030a0101303302142498dc6283930996fd8bf23a37acbe26a3bed457170d3234303632373133313733385a300c300a0603551d1504030a010130340215008a66f1a749488667689cc3903ac54c662b712e73170d3234303632373133313733385a300c300a0603551d1504030a01013034021500afc13610bdd36cb7985d106481a880d3a01fda07170d3234303632373133313733385a300c300a0603551d1504030a01013034021500efe04b2c33d036aac96ca673bf1e9a47b64d5cbb170d3234303632373133313733385a300c300a0603551d1504030a0101303402150083d9ac8d8bb509d1c6c809ad712e8430559ed7f3170d3234303632373133313733385a300c300a0603551d1504030a0101303302147931fd50b5071c1bbfc5b7b6ded8b45b9d8b8529170d3234303632373133313733385a300c300a0603551d1504030a0101303302141fa20e2970bde5d57f7b8ddf8339484e1f1d0823170d3234303632373133313733385a300c300a0603551d1504030a0101303302141e87b2c3b32d8d23e411cef34197b95af0c8adf5170d3234303632373133313733385a300c300a0603551d1504030a010130340215009afd2ee90a473550a167d996911437c7502d1f09170d3234303632373133313733385a300c300a0603551d1504030a0101303302144481b0f11728a13b696d3ea9c770a0b15ec58dda170d3234303632373133313733385a300c300a0603551d1504030a01013034021500a7859f57982ef0e67d37bc8ef2ef5ac835ff1aa9170d3234303632373133313733385a300c300a0603551d1504030a0101303302147ae37748a9f912f4c63ba7ab07c593ce1d1d1181170d3234303632373133313733385a300c300a0603551d1504030a01013033021413884b33269938c195aa170fca75da177538df0b170d3234303632373133313733385a300c300a0603551d1504030a0101303302142c3cc6fe9279db1516d5ce39f2a898cda5a175e1170d3234303632373133313733385a300c300a0603551d1504030a010130330214717948687509234be979e4b7dce6f31bef64b68c170d3234303632373133313733385a300c300a0603551d1504030a010130340215009d76ef2c39c136e8658b6e7396b1d7445a27631f170d3234303632373133313733385a300c300a0603551d1504030a01013034021500c3e025fca995f36f59b48467939e3e34e6361a6f170d3234303632373133313733385a300c300a0603551d1504030a010130340215008c5f6b3257da05b17429e2e61ba965d67330606a170d3234303632373133313733385a300c300a0603551d1504030a01013034021500a17c51722ec1e0c3278fe8bdf052059cbec4e648170d3234303632373133313733385a300c300a0603551d1504030a0101a02f302d300a0603551d140403020101301f0603551d23041830168014956f5dcdbd1be1e94049c9d4f433ce01570bde54300a06082a8648ce3d04030203480030450220020322ffb92ae4bddb43c36c845e51e0f68368b94c82d2ca31345fa774068864022100c3251194239d58d449fec2c5abbbc9a81934f9d205150e0a726e06c29c75cdf9";

    bytes memory rootCrlDer =
        hex"308201223081c8020101300a06082a8648ce3d0403023068311a301806035504030c11496e74656c2053475820526f6f74204341311a3018060355040a0c11496e74656c20436f72706f726174696f6e3114301206035504070c0b53616e746120436c617261310b300906035504080c024341310b3009060355040613025553170d3234303332303139313933305a170d3235303430333139313933305aa02f302d300a0603551d140403020101301f0603551d2304183016801422650cd65a9d3489f383b49552bf501b392706ac300a06082a8648ce3d0403020349003046022100e7606fef2da68785a0c39bc34ac344c9e2d6ed4b0223e79a6c6297d421b73784022100fc1587aece4296d5e9370fd6a444a72d03c598cb21dc8104c55b127b766ea82b";
        
        // upsert rootca
        pcsDao.upsertPcsCertificates(CA.ROOT, rootCaDer);

        // upsert tcb signing ca
        pcsDao.upsertPcsCertificates(CA.SIGNING, tcbDer);

        // upsert Platform intermediate CA
        pcsDao.upsertPcsCertificates(CA.PLATFORM, platformDer);

        // upsert pck platform crl
        pcsDao.upsertPckCrl(CA.PLATFORM, platformCrlDer);

        // upsert rootca crl
        pcsDao.upsertRootCACrl(rootCrlDer);
    }

    function _deployP256() private {
        address P256_VERIFIER = 0xc2b78104907F722DABAc4C69f826a522B2754De4;
        uint256 orig_codesize = P256_VERIFIER.code.length;
        if (orig_codesize > 0) return;
        
        bytes memory txdata =
            hex"00000000000000000000000000000000000000000000000000000000000000006080806040523461001657610dd1908161001c8239f35b600080fdfe60e06040523461001a57610012366100c7565b602081519101f35b600080fd5b6040810190811067ffffffffffffffff82111761003b57604052565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b60e0810190811067ffffffffffffffff82111761003b57604052565b90601f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0910116810190811067ffffffffffffffff82111761003b57604052565b60a08103610193578060201161001a57600060409180831161018f578060601161018f578060801161018f5760a01161018c57815182810181811067ffffffffffffffff82111761015f579061013291845260603581526080356020820152833560203584356101ab565b15610156575060ff6001915b5191166020820152602081526101538161001f565b90565b60ff909161013e565b6024837f4e487b710000000000000000000000000000000000000000000000000000000081526041600452fd5b80fd5b5080fd5b5060405160006020820152602081526101538161001f565b909283158015610393575b801561038b575b8015610361575b6103585780519060206101dc818301938451906103bd565b1561034d57604051948186019082825282604088015282606088015260808701527fffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc63254f60a08701527fffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551958660c082015260c081526102588161006a565b600080928192519060055afa903d15610345573d9167ffffffffffffffff831161031857604051926102b1857fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f8401160185610086565b83523d828585013e5b156102eb57828280518101031261018c5750015190516102e693929185908181890994099151906104eb565b061490565b807f4e487b7100000000000000000000000000000000000000000000000000000000602492526001600452fd5b6024827f4e487b710000000000000000000000000000000000000000000000000000000081526041600452fd5b6060916102ba565b505050505050600090565b50505050600090565b507fffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc6325518310156101c4565b5082156101bd565b507fffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc6325518410156101b6565b7fffffffff00000001000000000000000000000000ffffffffffffffffffffffff90818110801590610466575b8015610455575b61044d577f5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b8282818080957fffffffff00000001000000000000000000000000fffffffffffffffffffffffc0991818180090908089180091490565b505050600090565b50801580156103f1575082156103f1565b50818310156103ea565b7f800000000000000000000000000000000000000000000000000000000000000081146104bc577fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0190565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b909192608052600091600160a05260a05193600092811580610718575b61034d57610516838261073d565b95909460ff60c05260005b600060c05112156106ef575b60a05181036106a1575050507f4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5957f6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c2969594939291965b600060c05112156105c7575050505050507fffffffff00000001000000000000000000000000ffffffffffffffffffffffff91506105c260a051610ca2565b900990565b956105d9929394959660a05191610a98565b9097929181928960a0528192819a6105f66080518960c051610722565b61060160c051610470565b60c0528061061b5750505050505b96959493929196610583565b969b5061067b96939550919350916001810361068857507f4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5937f6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c29693610952565b979297919060a05261060f565b6002036106985786938a93610952565b88938893610952565b600281036106ba57505050829581959493929196610583565b9197917ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd0161060f575095508495849661060f565b506106ff6080518560c051610722565b8061070b60c051610470565b60c052156105215761052d565b5060805115610508565b91906002600192841c831b16921c1681018091116104bc5790565b8015806107ab575b6107635761075f91610756916107b3565b92919091610c42565b9091565b50507f6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296907f4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f590565b508115610745565b919082158061094a575b1561080f57507f6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c29691507f4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5906001908190565b7fb01cbd1c01e58065711814b583f061e9d431cca994cea1313449bf97c840ae0a917fffffffff00000001000000000000000000000000ffffffffffffffffffffffff808481600186090894817f94e82e0c1ed3bdb90743191a9c5bbf0d88fc827fd214cc5f0b5ec6ba27673d6981600184090893841561091b575050808084800993840994818460010994828088600109957f6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c29609918784038481116104bc5784908180867fffffffff00000001000000000000000000000000fffffffffffffffffffffffd0991818580090808978885038581116104bc578580949281930994080908935b93929190565b9350935050921560001461093b5761093291610b6d565b91939092610915565b50506000806000926000610915565b5080156107bd565b91949592939095811580610a90575b15610991575050831580610989575b61097a5793929190565b50600093508392508291508190565b508215610970565b85919294951580610a88575b610a78577fffffffff00000001000000000000000000000000ffffffffffffffffffffffff968703918783116104bc5787838189850908938689038981116104bc5789908184840908928315610a5d575050818880959493928180848196099b8c9485099b8c920999099609918784038481116104bc5784908180867fffffffff00000001000000000000000000000000fffffffffffffffffffffffd0991818580090808978885038581116104bc578580949281930994080908929190565b965096505050509093501560001461093b5761093291610b6d565b9550509150915091906001908190565b50851561099d565b508015610961565b939092821580610b65575b61097a577fffffffff00000001000000000000000000000000ffffffffffffffffffffffff908185600209948280878009809709948380888a0998818080808680097fffffffff00000001000000000000000000000000fffffffffffffffffffffffc099280096003090884808a7fffffffff00000001000000000000000000000000fffffffffffffffffffffffd09818380090898898603918683116104bc57888703908782116104bc578780969481809681950994089009089609930990565b508015610aa3565b919091801580610c3a575b610c2d577fffffffff00000001000000000000000000000000ffffffffffffffffffffffff90818460020991808084800980940991817fffffffff00000001000000000000000000000000fffffffffffffffffffffffc81808088860994800960030908958280837fffffffff00000001000000000000000000000000fffffffffffffffffffffffd09818980090896878403918483116104bc57858503928584116104bc5785809492819309940890090892565b5060009150819081908190565b508215610b78565b909392821580610c9a575b610c8d57610c5a90610ca2565b9182917fffffffff00000001000000000000000000000000ffffffffffffffffffffffff80809581940980099009930990565b5050509050600090600090565b508015610c4d565b604051906020918281019183835283604083015283606083015260808201527fffffffff00000001000000000000000000000000fffffffffffffffffffffffd60a08201527fffffffff00000001000000000000000000000000ffffffffffffffffffffffff60c082015260c08152610d1a8161006a565b600080928192519060055afa903d15610d93573d9167ffffffffffffffff83116103185760405192610d73857fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f8401160185610086565b83523d828585013e5b156102eb57828280518101031261018c5750015190565b606091610d7c56fea2646970667358221220fa55558b04ced380e93d0a46be01bb895ff30f015c50c516e898c341cd0a230264736f6c63430008150033";
        (bool succ,) = address(0x4e59b44847b379578588920cA78FbF26c0B4956C).call(txdata);
        require(succ, "Failed to deploy P256");

        // check code
        uint256 codesize = P256_VERIFIER.code.length;
        require(codesize > 0, "P256 deployed to the wrong address");
    }
}
