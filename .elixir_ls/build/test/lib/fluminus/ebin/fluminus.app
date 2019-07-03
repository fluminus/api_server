{application,fluminus,
             [{applications,[kernel,stdlib,elixir,logger,httpoison]},
              {description,"A library for the reverse-engineered LumiNUS API (https://luminus.nus.edu.sg)"},
              {modules,['Elixir.Fluminus','Elixir.Fluminus.API',
                        'Elixir.Fluminus.API.File',
                        'Elixir.Fluminus.API.Module',
                        'Elixir.Fluminus.Application',
                        'Elixir.Fluminus.Authorization',
                        'Elixir.Fluminus.Constants',
                        'Elixir.Fluminus.HTTPClient']},
              {registered,[]},
              {vsn,"0.2.5"},
              {mod,{'Elixir.Fluminus.Application',[{env,prod}]}}]}.