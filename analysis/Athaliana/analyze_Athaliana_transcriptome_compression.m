clear;
rng('default');

cd(matdir)
startup

cd(matdir('tradict/NCBI_SRA/Athaliana/'));

%mainDataFile = 'NCBI_SRA_Athaliana_full_data_up_to_18May2015_processed.mat';
mainDataFile = 'NCBI_SRA_Athaliana_full_data_up_to_18May2015_processed_updated_09June2015.mat';
queryTable = 'Athaliana_query_table_18May2015_shuffled_.csv';

% Some pre-processing.
% Basic quality checks, and sample thresholding.
% Isoform collapsing to genes
% Keeping of nuclear protein coding genes.
% Check TPM profiles
if true; NCBI_SRA_Athaliana_preprocess(mainDataFile, queryTable); return; end

load(mainDataFile);
lY = log10(Y' + 0.1);

% Plots of Clock genes.
if false; NCBI_SRA_Athaliana_plot_clock_genes(lY, tids); end


% Coefficient of variation density plot.
if false; logcov = NCBI_SRA_Athalianal_COV_density_plot(Y); end

% Perc. variation explained vs eigengene.
if true; [coef, pexp] = NCBI_SRA_Athaliana_pexp_vs_components(lY); end

% PCA plots
if false
    load('PCA_pexp_vs_eigengene_params.mat');
    NCBI_SRA_Athaliana_plot_PCA( lY, coef, qt, pexp )
end

% Convergence of data clusters along the principal components.
if false; 
    save('PCA_pexp_vs_eigengene_params.mat', 'coef', 'pexp');
    NCBI_SRA_PC_stability(coef, pexp, lY, qt);
end

% Marker OMP decomposition
% Run on $pw
if false
    somp = marker_OMP(standardize(lY), 0.25, 'savememory', true, 'maxfeatures', 100);
    save('NCBI_SRA_Athaliana_marker_OMP_decomposition.mat', 'somp');
end

% Tradict new data from old
if false
    load('NCBI_SRA_Athaliana_marker_OMP_decomposition.mat');
    
    NCBI_SRA_Athaliana_tradict_new_from_old( lY, qt, somp, '05-Mar-2015' );
    
end

% Tradiction power analysis
if false
    if true
        % perform the analysis and make graphics
        PROPVARUNEXPCUTOFF = 0;
        MAXFEATS = 100;
        SEED = 1;
        matfile = ['NCBI_SRA_Athaliana_tradict_power_analysis_punexp_', num2str(100*PROPVARUNEXPCUTOFF), ...
                '_maxfeats_', num2str(MAXFEATS), '_seed_', num2str(SEED), '.mat'];

        load(matfile) % results in memory.
        NCBI_SRA_Athaliana_power_analysis(lY,qt, '05-Mar-2015', tids, 'poweranalysisresults', results);
    else
        NCBI_SRA_Athaliana_power_analysis(lY,qt, '05-Mar-2015', tids);
    end
end

% Context specific performance failed.
if false
    NCBI_SRA_Athaliana_context_specific_perfomance(lY,qt, '05-Mar-2015');
end



% Supervised model. Tradiction. OLD CODE (see above).
if false
    
    if false
        load('PCA_pexp_vs_eigengene_params.mat');
        NMARKERS = 100;
        I = eye(100);
        Rs = corr( coef(:,1:size(I,2))', I);

        [~,mind] = max(Rs);

        cvind = crossvalind('Kfold',size(lY,1),10);

        lY_train = lY(cvind ~= 1,:);
        x_train = lY_train(:,mind);

        model = tratrain(lY_train,x_train,'lambda', 55);

        lY_validate = lY(cvind == 1, :);
        x_validate = lY_validate(:,mind);

        yhat = tradict(x_validate, model);

        Rsq = zeros(1, size(yhat,2));
        slopes = zeros(1, size(yhat,2));
        for i = 1 : length(Rsq)
            Rsq(i) = corr(yhat(:,i), lY_validate(:,i));
            c = pca([lY_validate(:,i), yhat(:,i)]);
            slopes(i) = c(2,1)/c(1,1);
        end

        save('tradict_results.mat');
    else
        load('tradict_results.mat');
        
        subplot(2,1,1)
        hist(Rsq,100);
        axis square
        ylabel('Frequency');
        xlabel('R^2 (prediction vs. actual)');
        
        subplot(2,1,2)
        hist(slopes,100);
        axis square
        ylabel('Frequency');
        xlabel('Slope (prediction vs. actual)');
        plotSave('figures/test_set_overall_prediction_quality.png');
        iminvert('figures/test_set_overall_prediction_quality.png');
        close
        
        rind = randsample(length(Rsq), 8, false);
        for i = 1 : length(rind)
            subplot(2,4,i)
            
            plot(lY_validate(:,rind(i)), yhat(:,rind(i)), '.k')
            title(tids{rind(i)});
            axis square;
            axis tight;
            buffer_axis;
            
            v = axis;
            v(1) = v(3);
            v(2) = v(4);
            axis(v);
            
            hold on
            plot([v(1) v(2)], [v(3) v(4)], '-r', 'LineWidth', 2);
        end
        plotSave('figures/test_set_prediction_examples.png');
        iminvert('figures/test_set_prediction_examples.png');
        close
        
    end
    
end

% True test. Comparison to Col-0 temperature perturbation.
if false
    old = cd('/Users/sbiswas/Documents/matlab/src/tradict/NCBI_SRA/Col0_temperature_test');
    dk = dataset('file','/Users/sbiswas/Documents/matlab/src/interactome/At_nuclear_protein_coding.txt', 'ReadObsNames', false, 'ReadVarNames', false);
    dko = dk.Var1;
    
    s22 = read_sailfish_output('Col0_22C_ZT0_quant_bias_corrected.sf');
    s27 = read_sailfish_output('Col0_27C_ZT0_quant_bias_corrected.sf');
    s22c = collapse_isoform_table(s22.table);
    s27c = collapse_isoform_table(s27.table);
    
    d22 = dataset('file', 'Col0_22C_ZT0.ct', 'ReadObsNames', true, 'ReadVarNames', false);
    d27 = dataset('file', 'Col0_27C_ZT0.ct', 'ReadObsNames', true, 'ReadVarNames', false);
    
    % Keep common features (should only be nuclear protein coding).
    [~,ia] = intersect(get(s22c, 'ObsNames'), tids);
    s22c = s22c(ia,:);
    s27c = s27c(ia,:);
    
    [~,ia] = intersect(get(d22, 'ObsNames'), tids);
    d22 = d22(ia,:);
    d27 = d27(ia,:);
    
    
    st = log10([s22c.TPM, s27c.TPM]+0.1); 
    dt = log10(1e6*relabund([d22.Var2, d27.Var2]'+1)');
    
    
    slfc = st(:,2) - st(:,1);
    dlfc = dt(:,2) - dt(:,1);    

    
    % Evaluate prediction accuracy.
    load('tradict_results.mat');
    
    
    yhat_col = tradict(st(mind,:)', model)';
    slfc_pred = yhat_col(:,2) - yhat_col(:,1);
    
    figure
    plottok = prod([d22.Var2, d27.Var2],2) > 0;
    plotmatrix([dt(plottok,1), st(plottok,1), yhat_col(plottok,1)], '.k')
    plotSave('figures/plotmatrix_standard_sailfish_sailfishpred_22C.png');
    iminvert('figures/plotmatrix_standard_sailfish_sailfishpred_22C.png');
    
    plotmatrix([dt(plottok,2), st(plottok,2), yhat_col(plottok,2)], '.k')
    plotSave('figures/plotmatrix_standard_sailfish_sailfishpred_27C.png');
    iminvert('figures/plotmatrix_standard_sailfish_sailfishpred_27C.png');
    
    close all
    
    
    figure;
    plot(dt(plottok,1), dt(plottok,2), '.k');
    axis square
    xlabel(['Col-0 22C ZT0', 10, 'Standard log_{10}(CPM)']);
    ylabel(['Col-0 27C ZT0', 10, 'Standard log_{10}(CPM)']);
    plotSave('figures/Col0_ZT0_27C_vs_22C_standard_pipeline.png');
    iminvert('figures/Col0_ZT0_27C_vs_22C_standard_pipeline.png');
    close
    
    
    figure;
    [ff,xi] = ksdensity(dt(:,2) - dt(:,1));
    jbfill(xi, ff, zeros(1,length(ff)), [0.3 0.3 0.3], [0.3 0.3 0.3], true, 0.6);
    axis square
    xlabel('log_2(27C/22C) Col-0 ZT0');
    ylabel('Density');
    plotSave('figures/Col0_ZT0_27C_vs_22C_standard_pipeline_log2FC.png');
    iminvert('figures/Col0_ZT0_27C_vs_22C_standard_pipeline_log2FC.png');
    close
    
    
    figure
    plot(dlfc(plottok), slfc(plottok), '.k');
    text(-1.5, 1.5, sprintf('R^2 = %0.2f', corr(dlfc(plottok), slfc(plottok))));
    axis([-2 2 -2 2]);
    axis square
    xlabel('log_{10}(27C/22C) Col-0 ZT0 Standard Pipeline');
    ylabel('log_{10}(27C/22C) Col-0 ZT0 Sailfish');
    set(gca, 'FontSize', 14)
    plotSave('figures/logFC_standard_vs_sailfish.png');
    iminvert('figures/logFC_standard_vs_sailfish.png');
    close
    
    figure
    plot(dlfc(plottok), slfc_pred(plottok), '.k');
    text(-1.5, 1.5, sprintf('R^2 = %0.2f', corr(dlfc(plottok), slfc_pred(plottok))));
    axis square
    axis([-2 2 -2 2]);
    xlabel('log_{10}(27C/22C) Col-0 ZT0 Standard Pipeline');
    ylabel('log_{10}(27C/22C) Col-0 ZT0 Tradict');
    set(gca, 'FontSize', 14)
    plotSave('figures/logFC_standard_vs_tradict.png');
    iminvert('figures/logFC_standard_vs_tradict.png');
    close
    
    
    
    cd(old)
end


% Toy example of tradict
if false
    n = 67;
    p = 100;
    x = zeros(n, p);
    kind = [25 80];
    
    x(:, kind(1)) = randn(n,1);
    x(:, kind(2)) = randn(n,1);
    [~,sidx] = sort(x(:,kind(1)));
    
    b = [[0.7*randn(1, p-72)-1; 0.7*randn(1,p-72) + 2], [0.7*randn(1, p-30) + 2; 0.7*randn(1,p-30) - 1]]  ;
    xfull = x;
    xfull(:, setdiff(1:p,kind)) = x(:,kind)*b;
    
    figure;
    imagesc(x(sidx,kind), [-2 2]); colormap(prgn);
    axis image
    set(gca, 'TickLength', [0 0]);
    set(gca, 'XTick', []);
    set(gca, 'YTick', []);
    plotSave('figures/toy_example/markers_train.png');
    iminvert('figures/toy_example/markers_train.png');
    close
    
    figure;
    imagesc(standardize(xfull(sidx,setdiff(1:p,kind))), [-2 2]); colormap(prgn)
    axis image
    set(gca, 'TickLength', [0 0]);
    set(gca, 'XTick', []);
    set(gca, 'YTick', []);
    plotSave('figures/toy_example/full_train.png');
    iminvert('figures/toy_example/full_train.png');
    close
    
    figure;
    imagesc(b); colormap(redbluecmap)
    axis image
    set(gca, 'TickLength', [0 0]);
    set(gca, 'XTick', []);
    set(gca, 'YTick', []);
    plotSave('figures/toy_example/coefs.png');
    iminvert('figures/toy_example/coefs.png');
    close
    
    nnew = 15;
    xnew = randn(nnew,2);
    ynew = xnew*b;
    
    [~,sidx2] = sort(xnew(:,1));
    
    imagesc(standardize(xnew(sidx2,:)), [-2 2]); colormap(prgn)
    axis image
    set(gca, 'TickLength', [0 0]);
    set(gca, 'XTick', []);
    set(gca, 'YTick', []);
    plotSave('figures/toy_example/markers_test.png');
    iminvert('figures/toy_example/markers_test.png');
    close
    
    imagesc(standardize(ynew(sidx2,:)), [-2 2]); colormap(prgn)
    axis image
    set(gca, 'TickLength', [0 0]);
    set(gca, 'XTick', []);
    set(gca, 'YTick', []);
    plotSave('figures/toy_example/full_test.png');
    iminvert('figures/toy_example/full_test.png');
    close
    
    
    
    
    
    
    
    
end