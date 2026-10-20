use base::config::keys;
use hbb_common::config;

const SERVER_HOST: &str = "rust.northwoodscomputerguy.com";
const RELAY_SERVER: &str = "rust.northwoodscomputerguy.com:21117";
const PUBLIC_KEY: &str = "sjVK2P8Cik7MW4v6sn1FhCN5RdRAK1BpqXlSDraF0qY=";

pub fn apply() {
    let Ok(mut overwrite) = config::OVERWRITE_SETTINGS.write() else {
        hbb_common::log::error!("NCG defaults: settings lock poisoned");
        return;
    };
    for (k, v) in [
        (keys::OPTION_CUSTOM_RENDEZVOUS_SERVER, SERVER_HOST),
        (keys::OPTION_RELAY_SERVER, RELAY_SERVER),
        (keys::OPTION_KEY, PUBLIC_KEY),
        (keys::OPTION_ENABLE_CHECK_UPDATE, "N"),
        (keys::OPTION_ALLOW_AUTO_UPDATE, "N"),
    ] {
        overwrite.insert(k.to_owned(), v.to_owned());
    }
}
