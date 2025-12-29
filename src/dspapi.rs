// dspapi.rs

/* DSP API Definitions */

#![allow(warnings)]

use std::sync::{Arc, Mutex};
use once_cell::sync::Lazy;

pub const DSPAPI_VERSION: &str = "0.0.1";

pub type NodeId = u32;
pub type ParamId = u32;
pub type PortId = u32;

// Global Response Queue: For the Engine to send telemetry/ACK back to GUI
pub static RESPONSE_QUEUE: Lazy<Arc<Mutex<Vec<Command>>>> = Lazy::new(|| {
    Arc::new(Mutex::new(Vec::new()))
});

#[derive(Debug, Clone, Copy)]
pub enum StatState {
    ACTIVE,
    INACTIVE,
    PAUSED,
}

/// The Universal Command structure.
/// To support "anything", the command_id acts as an OpCode:
/// 0: Add Node, 1: Remove Node, 2: Set Parameter, 3: Connect Routing
pub struct Command {
    pub command_id: u32,
    pub description: &'static str,
    pub payload_size: usize,
    pub payload: Vec<u8>, // Can hold floats, strings, or serialized structs
    pub node_id: NodeId,
    pub param_id: ParamId,
    pub port_id: PortId,
    pub stat: StatState,
}

impl Command {
    pub fn new(command_id: u32, description: &'static str, payload: Vec<u8>, node_id: NodeId, param_id: ParamId, port_id: PortId, stat: StatState) -> Self {
        Command {
            command_id,
            description,
            payload_size: payload.len(),
            payload,
            node_id,
            param_id,
            port_id,
            stat,
        }
    }

    pub fn send(self) {
        if let Ok(engine) = crate::dspengine::DSPENGINE.lock() {
            if let Ok(mut queue) = engine.command_queue.lock() {
                queue.push(self);
            }
        }
    }

    pub fn receive_all() -> Vec<Self> {
        if let Ok(mut queue) = RESPONSE_QUEUE.lock() {
            return queue.drain(..).collect();
        }
        vec![]
    }
}