% run the actual wavefield propagation


%% initialise dynamic fields ----------------------------------------------
% both forward and adjoint
initialise_dynamic_fields;  % this just makes all dynamic field (v, stress,
                            % derivatives of v and stress wherever needed
                            % with zeros(dimensions).


%% initialise absorbing boundary taper a la Cerjan ------------------------

absbound=ones(nx,nz);
init_absbound;

%%
%==========================================================================
% iterate
%==========================================================================

disp 'iterating...'

if (strcmp(simulation_mode,'forward'))
    fig_vel = figure;
    if(strcmp(wave_propagation_type,'both'))
        set(fig_vel,'OuterPosition',pos_vel_nplots3);
    else
        set(fig_vel,'OuterPosition',pos_vel);
    end
elseif (strcmp(simulation_mode,'adjoint'))
    Kx=0;
    Ky=0;
    Kz=0;
    fig_adjoint = figure;
    if(strcmp(wave_propagation_type,'SH'))
        set(fig_adjoint,'OuterPosition',pos_adj_1)
        nrows=1;
    elseif(strcmp(wave_propagation_type,'PSV'))
        set(fig_adjoint,'OuterPosition',pos_adj_2)
        nrows=2;
    elseif(strcmp(wave_propagation_type,'both'))
        set(fig_adjoint,'OuterPosition',pos_adj_3)
        nrows=3;
    end
    disp 'nrows',num2str(nrows)
else
    disp 'WARNING: the simulation mode is not one accounted for'
end
%%
for n=1:nt
    
    %- compute divergence of current stress tensor ------------------------
    
    if(strcmp(wave_propagation_type,'SH'))
        DSY=div_s(sxy,szy,dx,dz,nx,nz,order);
    elseif(strcmp(wave_propagation_type,'PSV'))
        [DSX,DSZ]=div_s_PSV(sxx,szz,sxz,dx,dz,nx,nz,order);
    elseif(strcmp(wave_propagation_type,'both'))
        DSY=div_s(sxy,szy,dx,dz,nx,nz,order);
        [DSX,DSZ]=div_s_PSV(sxx,szz,sxz,dx,dz,nx,nz,order);
    end
    
    %- add point sources --------------------------------------------------
    
    if (strcmp(simulation_mode,'forward') || strcmp(simulation_mode,'forward_green') ||  strcmp(simulation_mode,'adjoint') )
    
        for i=1:ns
            if(strcmp(wave_propagation_type,'SH'))
                DSY(src_x_id(i),src_z_id(i))=DSY(src_x_id(i),src_z_id(i))+stf(2,i,n);
            elseif(strcmp(wave_propagation_type,'PSV'))
                DSX(src_x_id(i),src_z_id(i))=DSX(src_x_id(i),src_z_id(i))+stf(1,i,n);                   %%%%%%%%% Beetje krukkig zo... kan het mooier?
                DSZ(src_x_id(i),src_z_id(i))=DSZ(src_x_id(i),src_z_id(i))+stf(3,i,n);
            elseif(strcmp(wave_propagation_type,'both'))
                DSY(src_x_id(i),src_z_id(i))=DSY(src_x_id(i),src_z_id(i))+stf(2,i,n);
                DSX(src_x_id(i),src_z_id(i))=DSX(src_x_id(i),src_z_id(i))+stf(1,i,n);                   %%%%%%%%% Beetje krukkig zo... kan het mooier?
                DSZ(src_x_id(i),src_z_id(i))=DSZ(src_x_id(i),src_z_id(i))+stf(3,i,n);
            end

        end
        
    end
    
    
    %- update velocity field ----------------------------------------------
    
    if(strcmp(wave_propagation_type,'SH'))
        vy=vy+dt*DSY./rho;
    elseif(strcmp(wave_propagation_type,'PSV'))
        vx=vx+dt*DSX(:,:)./rho;
        vz=vz+dt*DSZ(:,:)./rho;
    elseif(strcmp(wave_propagation_type,'both'))
        vy=vy+dt*DSY./rho;
        vx=vx+dt*DSX(:,:)./rho;
        vz=vz+dt*DSZ(:,:)./rho;
    end
    
                        % just a test to see whether DS and v produce values
                        % [max(max(DS)),max(max(DSX)),max(max(DSZ)); max(max(v)),max(max(vx)),max(max(vz))]
    
    
    %- apply absorbing boundary taper -------------------------------------
    
    if(strcmp(wave_propagation_type,'SH'))
        vy=vy.*absbound;
    elseif(strcmp(wave_propagation_type,'PSV'))
        vx=vx.*absbound;
        vz=vz.*absbound;
    elseif(strcmp(wave_propagation_type,'both'))
        vy=vy.*absbound;
        vx=vx.*absbound;
        vz=vz.*absbound;
    end
    
    %- compute derivatives of current velocity and update stress tensor ---
    
    if(strcmp(wave_propagation_type,'SH'))
        sxy=sxy+dt*mu(1:nx-1,1:nz).*dx_v(vy,dx,dz,nx,nz,order);
        szy=szy+dt*mu(:,1:nz-1).*dz_v(vy,dx,dz,nx,nz,order);
    elseif(strcmp(wave_propagation_type,'PSV'))
        [GVxx,GVxz,GVzx,GVzz]=grad_v_PSV(vx,vz,dx,dz,nx,nz,order);
        sxx=sxx+dt*( (lambda+2*mu).*GVxx(:,:) + lambda.*GVzz(:,:) );
        szz=szz+dt*( (lambda+2*mu).*GVzz(:,:) + lambda.*GVxx(:,:) );
        sxz=sxz+dt*( mu.*(GVxz(:,:) + GVzx(:,:)) );
    elseif(strcmp(wave_propagation_type,'both'))
        sxy=sxy+dt*mu(1:nx-1,1:nz).*dx_v(vy,dx,dz,nx,nz,order);
        szy=szy+dt*mu(:,1:nz-1).*dz_v(vy,dx,dz,nx,nz,order);
        [GVxx,GVxz,GVzx,GVzz]=grad_v_PSV(vx,vz,dx,dz,nx,nz,order);
        sxx=sxx+dt*( (lambda+2*mu).*GVxx(:,:) + lambda.*GVzz(:,:) );
        szz=szz+dt*( (lambda+2*mu).*GVzz(:,:) + lambda.*GVxx(:,:) );
        sxz=sxz+dt*( mu.*(GVxz(:,:) + GVzx(:,:)) );
    end
    
                                        % testing the GV values
                                        % [max(max(GVxx)),max(max(GVxz));max(max(GVzx)),max(max(GVzz))]
                                        % [min(min(GVxx)),min(min(GVxz));min(min(GVzx)),min(min(GVzz))]

    
    
    if (strcmp(simulation_mode,'forward'))
        
        %- record velocity seismograms ----------------------------------------
        for k=1:n_receivers
            if(strcmp(wave_propagation_type,'SH'))
                v_rec_y(k,n)=vy(rec_x_id(k),rec_z_id(k));
            elseif(strcmp(wave_propagation_type,'PSV'))
                v_rec_x(k,n)=vx(rec_x_id(k),rec_z_id(k));
                v_rec_z(k,n)=vz(rec_x_id(k),rec_z_id(k));
            elseif(strcmp(wave_propagation_type,'both'))
                v_rec_y(k,n)=vy(rec_x_id(k),rec_z_id(k));
                v_rec_x(k,n)=vx(rec_x_id(k),rec_z_id(k));
                v_rec_z(k,n)=vz(rec_x_id(k),rec_z_id(k));
            end
        end
        
        %- store time-reversed history ----------------------------------------
        
        % save every 5th velocity field to the big-ass 3 direction matrix
        if (mod(n,5)==0)
            if(strcmp(wave_propagation_type,'SH'))
                vy_forward(nt/5+1-n/5,:,:)=vy(:,:);
            elseif(strcmp(wave_propagation_type,'PSV'))
                vx_forward(nt/5+1-n/5,:,:)=vx(:,:);
                vz_forward(nt/5+1-n/5,:,:)=vz(:,:);
            elseif(strcmp(wave_propagation_type,'both'))
                vy_forward(nt/5+1-n/5,:,:)=vy(:,:);
                vx_forward(nt/5+1-n/5,:,:)=vx(:,:);
                vz_forward(nt/5+1-n/5,:,:)=vz(:,:);
            end
        end
        
        %     end
    
    
        %- plot velocity field every so manyth time step ----------------------
        if (mod(n,plot_every)==0)
            plot_velocity_field;
        end
        
        
    elseif(strcmp(simulation_mode,'adjoint'))
        %% plot and compute kernel every 5th iteration -----------------------
        % ONLY ADJOINT!!!!
        if (mod(n,5)==0)
            
            
            %% do adjoint-related operations and calculations
            
            % get forward field (remember: saved backwards in time)
            vy_forward_snapshot = squeeze(vy_forward(n/5,:,:));
            vx_forward_snapshot = squeeze(vx_forward(n/5,:,:));
            vz_forward_snapshot = squeeze(vz_forward(n/5,:,:));
            
            % interaction between forwerd and adjoint field
            interaction_y=vy.*vy_forward_snapshot;
            interaction_x=vx.*vx_forward_snapshot;
            interaction_z=vz.*vz_forward_snapshot;
            
            % kernel
            Ky=Ky-interaction_y*dt; % The minus sign is needed because we run backwards in time.
            Kx=Kx-interaction_x*dt; 
            Kz=Kz-interaction_z*dt; 
            
            %% plot adjoint fields (i.e. adjoint field + the above)
            plot_adjoint_field;
            
        end
    end
    
end