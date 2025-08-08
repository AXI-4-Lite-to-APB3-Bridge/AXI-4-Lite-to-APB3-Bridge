class axi2apb_env extends uvm_env;
  
  `uvm_component_utils(axi2apb_env)
  
  axi_agent     axi_agent1;
  apb_agent     apb_agent1;
  scoreboard    sb;
    
  axi_protocol_checker axi_checker;
  apb_protocol_checker apb_checker;

  function new(string name = "axi2apb_env", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Entered build phase of Environment"), UVM_MEDIUM);

    axi_agent1 = axi_agent::type_id::create("axi_agent1", this);
    apb_agent1 = apb_agent::type_id::create("apb_agent1", this);

    sb = scoreboard::type_id::create("sb", this);
    
    // protocol checkers
    axi_checker = axi_protocol_checker::type_id::create("axi_checker", this);
    apb_checker = apb_protocol_checker::type_id::create("apb_checker", this);
    
    uvm_config_db#(uvm_active_passive_enum)::set(this, "axi_agent*", "is_active", UVM_ACTIVE);   // AXI drives transactions
    uvm_config_db#(uvm_active_passive_enum)::set(this, "apb_agent*", "is_active", UVM_PASSIVE);  // APB only monitors
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    
    //  monitors to scoreboard connects
    axi_agent1.monitor.item_collected_port.connect(sb.axi_imp);
    apb_agent1.monitor.item_collected_port.connect(sb.apb_imp);
  endfunction

endclass
